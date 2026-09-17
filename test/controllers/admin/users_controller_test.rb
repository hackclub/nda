require "test_helper"

class Admin::UsersControllerTest < ActionController::TestCase
  tests Admin::UsersController

  setup do
    @admin = users(:two)
    @admin.update!(admin: true)
    session[:user_id] = @admin.id
  end

  test "moves a legacy member to the current NDA flow without deleting their old signature" do
    user = users(:one)
    legacy = create_legacy_signature(user)

    assert_difference("AdminAction.count") do
      post :require_current_nda, params: { id: user.id, reason: "Testing the revised agreement" }
    end

    assert_redirected_to admin_root_path
    assert_predicate user.reload, :current_nda_required_at?
    assert NdaSignature.exists?(legacy.id)
    action = AdminAction.last
    assert_equal "require_current_nda", action.action
    assert_equal NdaDocument::VERSION, action.details["document_version"]
  end

  test "moving to the current NDA requires a reason" do
    assert_no_difference("AdminAction.count") do
      post :require_current_nda, params: { id: users(:one).id }
    end

    assert_not users(:one).reload.current_nda_required_at?
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
