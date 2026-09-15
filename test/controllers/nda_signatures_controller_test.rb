require "test_helper"

class NdaSignaturesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get nda_signature_url
    assert_redirected_to root_url
  end
end

class NdaSignaturesControllerPdfTest < ActionController::TestCase
  tests NdaSignaturesController

  setup { session[:user_id] = users(:one).id }

  test "hands a signed member their agreement as a PDF" do
    signature = create_signature(users(:one), signed_at: Time.current)

    get :show, format: :pdf

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/filename="Ada Lovelace - Hack Club Contributor NDA.pdf"/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF-"), "expected a PDF"
    assert_equal NdaPdf.call(signature).bytesize, response.body.bytesize
  end

  test "has no PDF to hand over before anyone has signed" do
    get :show, format: :pdf

    assert_redirected_to nda_signature_path
  end

  test "offers the download on the receipt" do
    create_signature(users(:one), signed_at: Time.current)

    get :show

    assert_select "a[href=?]", nda_signature_path(format: :pdf)
  end

  test "tells a legacy holder they are already covered instead of nothing" do
    create_legacy_signature(users(:one))

    get :show

    assert_select "p.flash-notice", /already have an NDA on file/i
    assert_select "a[href=?]", legacy_nda_import_path
  end
end

class NdaSignaturesControllerFormTest < ActionController::TestCase
  tests NdaSignaturesController

  test "prefills the legal name from the Hack Club profile" do
    session[:user_id] = users(:one).id
    get :show

    assert_select "input[name='user[legal_first_name]'][value='Ada']"
    assert_select "input[name='user[legal_last_name]'][value='Lovelace']"
    assert_select "input[name='user[birthdate]'][autocomplete='bday']"
    assert_select "input[name='cosigner_name'][autocomplete='off']"
    assert_select "input[name='cosigner_email'][autocomplete='off']"
    assert_select "select[name='user[country]'] option[value='United States']"
  end
end

class NdaSignaturesControllerRetryTest < ActionController::TestCase
  include ActiveJob::TestHelper

  tests NdaSignaturesController

  setup do
    session[:user_id] = users(:one).id
  end

  test "keeps entered details and returns to the video step when verification fails" do
    singleton = PledgeValidator.singleton_class
    original = singleton.instance_method(:verify!)
    singleton.define_method(:verify!) { |_video, user:| raise PledgeValidator::Rejected, "No speech detected." }
    previous_token = ENV["SLACK_BOT_TOKEN"]
    ENV["SLACK_BOT_TOKEN"] = "test-token"

    assert_enqueued_with(job: NotifyNdaFailedJob, args: [ users(:one).id ]) do
      post :create, params: {
        accepted: "1",
        identity_video: fixture_file_upload("pledge.webm", "video/webm"),
        signed_name: "Ada Lovelace",
        user: SIGNING_DETAILS
      }
    end

    assert_response :unprocessable_entity
    assert_select "[data-wizard][data-initial-step='2']"
    assert_select "input[name='user[address_line_1]'][value='15 Falls Rd']"
    assert_select "input[name='signed_name'][value='Ada Lovelace']"
    assert_select "select[name='user[country]'] option[selected][value='United States']"
    assert_select ".flash-alert", text: "No speech detected."
  ensure
    ENV["SLACK_BOT_TOKEN"] = previous_token
    singleton&.define_method(:verify!, original) if original
  end
end

class NdaSignaturesControllerSuccessTest < ActionController::TestCase
  include ActiveJob::TestHelper

  tests NdaSignaturesController

  setup do
    session[:user_id] = users(:one).id
  end

  test "queues a Slack notification after a valid signature when Slack is configured" do
    validator = PledgeValidator.singleton_class
    original = validator.instance_method(:verify!)
    validator.define_method(:verify!) do |*, **|
      PledgeValidator::Result.new(transcript: "I pledge.", score: 1.0)
    end
    previous_token = ENV["SLACK_BOT_TOKEN"]
    ENV["SLACK_BOT_TOKEN"] = "test-token"

    assert_enqueued_with(job: NotifyNdaSignedJob) do
      post :create, params: {
        accepted: "1",
        identity_video: fixture_file_upload("pledge.webm", "video/webm"),
        signed_name: "Ada Lovelace",
        user: SIGNING_DETAILS
      }
    end

    assert_redirected_to nda_signature_path
  ensure
    ENV["SLACK_BOT_TOKEN"] = previous_token
    validator&.define_method(:verify!, original) if original
  end
end
