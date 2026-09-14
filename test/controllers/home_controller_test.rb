require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the landing page" do
    get root_url
    assert_response :success
    assert_select "link[rel='icon'][href='https://assets.hackclub.com/icon-rounded.png']"
    assert_select "h1", "Hack Club NDA"
  end
end
