require "test_helper"

class NdaSignaturesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get nda_signature_url
    assert_redirected_to root_url
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
  tests NdaSignaturesController

  setup do
    session[:user_id] = users(:one).id
  end

  test "keeps entered details and returns to the video step when verification fails" do
    singleton = PledgeValidator.singleton_class
    original = singleton.instance_method(:verify!)
    singleton.define_method(:verify!) { |_video, user:| raise PledgeValidator::Rejected, "No speech detected." }

    post :create, params: {
      accepted: "1",
      identity_video: fixture_file_upload("pledge.webm", "video/webm"),
      signed_name: "Ada Lovelace",
      user: SIGNING_DETAILS
    }

    assert_response :unprocessable_entity
    assert_select "[data-wizard][data-initial-step='2']"
    assert_select "input[name='user[address_line_1]'][value='15 Falls Rd']"
    assert_select "input[name='signed_name'][value='Ada Lovelace']"
    assert_select "select[name='user[country]'] option[selected][value='United States']"
    assert_select ".flash-alert", text: "No speech detected."
  ensure
    singleton&.define_method(:verify!, original) if original
  end
end
