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
      perform_enqueued_jobs(only: SignatureCompletedJob) do
        post :create, params: {
          accepted: "1",
          identity_video: fixture_file_upload("pledge.webm", "video/webm"),
          signed_name: "Ada Lovelace",
          user: SIGNING_DETAILS
        }
      end
    end

    assert_redirected_to nda_signature_path
  ensure
    ENV["SLACK_BOT_TOKEN"] = previous_token
    validator&.define_method(:verify!, original) if original
  end
end

class NdaSignaturesControllerMinorTest < ActionController::TestCase
  tests NdaSignaturesController

  MINOR_DETAILS = SIGNING_DETAILS.merge(birthdate: Date.new(2011, 3, 4)).freeze

  setup do
    session[:user_id] = users(:one).id
    @validator = PledgeValidator.singleton_class
    @original = @validator.instance_method(:verify!)
    @validator.define_method(:verify!) do |*, **|
      PledgeValidator::Result.new(transcript: "I pledge.", score: 1.0)
    end
  end

  teardown { @validator.define_method(:verify!, @original) }

  def sign_as_minor
    with_stubbed_mail do
      post :create, params: {
        accepted: "1",
        identity_video: fixture_file_upload("pledge.webm", "video/webm"),
        signed_name: "Ada Lovelace",
        cosigner_name: "Byron Lovelace",
        cosigner_email: "parent@example.com",
        user: MINOR_DETAILS
      }
    end
    users(:one).signature_for_current_version
  end

  test "a minor's signature waits for the guardian and emails them a link" do
    signature = sign_as_minor

    assert_predicate signature, :awaiting_cosigner?
    assert_nil users(:one).reload.reportable_nda_signature
    assert_equal [ "parent@example.com" ], sent_mail_for(:cosign_request).map { _1[:to] }
  end

  test "nothing is announced or pushed to Airtable while consent is outstanding" do
    assert_no_enqueued_jobs(only: [ SignatureCompletedJob, NotifyNdaSignedJob, SyncSignatureToAirtableJob ]) do
      sign_as_minor
    end
  end

  test "the agreement is not downloadable until the guardian has signed" do
    sign_as_minor
    @request.env.delete("CONTENT_TYPE")

    get :show, format: :pdf
    assert_redirected_to nda_signature_path
  end

  test "a resend issues a fresh link but not a flood of them" do
    signature = sign_as_minor
    first = signature.cosigner_token_digest

    with_stubbed_mail { post :resend_cosigner_invite }
    assert_equal first, signature.reload.cosigner_token_digest, "a resend moments later is ignored"

    signature.update!(cosigner_invited_at: 1.hour.ago)
    with_stubbed_mail { post :resend_cosigner_invite }
    assert_not_equal first, signature.reload.cosigner_token_digest
  end
end
