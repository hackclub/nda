require "test_helper"

class InfoControllerTest < ActionDispatch::IntegrationTest
  test "renders the information page" do
    get info_url

    assert_response :success
    assert_select "h1", "A little more information. A lot more clarity."
    assert_select ".info-page"
  end

  test "shows sign-in link when signed out" do
    get info_url

    assert_response :success
    assert_select "a[href='#{login_path}']",
                  "Sign in to review the agreement"
  end

  test "parents route is not available" do
    assert_raises(ActionController::RoutingError) do
      get "/parents"
    end
  end

  test "shows NDA signing link when signed in" do
    session[:user_id] = users(:one).id

    get info_url

    assert_response :success
    assert_select "a[href='#{nda_signature_path}']",
                  "Go to the NDA signing page"
  end
end
