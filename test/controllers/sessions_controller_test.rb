require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "logout clears the session" do
    delete logout_url
    assert_redirected_to root_url
  end
end
