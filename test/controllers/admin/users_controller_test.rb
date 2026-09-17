require "test_helper"

class Admin::UsersControllerTest < ActionController::TestCase
  tests Admin::UsersController

  setup do
    @admin = users(:two)
    @admin.update!(admin: true)
    session[:user_id] = @admin.id
  end

  test "reset removes only the current NDA and leaves an audit trail" do
    user = users(:one)
    current = create_signature(user, signed_at: Time.current)
    legacy = create_legacy_signature(user)

    assert_difference("NdaSignature.count", -1) do
      post :reset_nda, params: { id: user.id, reason: "Needs to accept the revised process" }
    end

    assert_not NdaSignature.exists?(current.id)
    assert NdaSignature.exists?(legacy.id)
    action = AdminAction.last
    assert_equal "reset_nda", action.action
    assert_equal current.id, action.subject_id
    assert_equal user, action.target_user
  end

  test "reset requires a reason" do
    signature = create_signature(users(:one), signed_at: Time.current)

    assert_no_difference("NdaSignature.count") do
      post :reset_nda, params: { id: users(:one).id }
    end
    assert NdaSignature.exists?(signature.id)
  end
end
