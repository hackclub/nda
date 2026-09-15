require "test_helper"

class Admin::LegacyNdaImportsControllerAccessTest < ActionDispatch::IntegrationTest
  test "turns away anyone who is not signed in" do
    get admin_legacy_nda_imports_url
    assert_redirected_to root_url
  end
end

class Admin::LegacyNdaImportsControllerTest < ActionController::TestCase
  tests Admin::LegacyNdaImportsController

  setup do
    @admin = users(:two)
    @admin.update!(admin: true)
    session[:user_id] = @admin.id
    @signature = create_legacy_signature(users(:one), verification_state: "needs_review")
    @import = users(:one).legacy_nda_imports.create!(state: "needs_review", nda_signature: @signature)
  end

  test "turns away a member who is not an admin" do
    session[:user_id] = users(:one).id
    get :index

    assert_redirected_to root_path
  end

  test "lists imports waiting for review" do
    get :index

    assert_response :success
    assert_select "article.review-item", 1
    assert_includes response.body, users(:one).slack_id
  end

  test "does not list imports that are already settled" do
    @signature.update!(verification_state: "approved")
    get :index

    assert_select "article.review-item", 0
  end

  test "approving files the signature and records who decided" do
    patch :update, params: { id: @signature.id, decision: "approve", note: "Checked with them on Slack" }

    @signature.reload
    assert_predicate @signature, :approved?
    assert_equal @admin, @signature.reviewed_by
    assert_not_nil @signature.reviewed_at
    assert_equal "Checked with them on Slack", @signature.review_note
    assert_equal @signature, users(:one).reportable_nda_signature
    assert_predicate @import.reload, :approved?
  end

  test "revoking releases the envelope so the rightful owner can claim it" do
    envelope = @signature.legacy_envelope_id

    patch :update, params: { id: @signature.id, decision: "revoke", note: "Not their document" }

    @signature.reload
    assert_predicate @signature, :rejected?
    assert_nil @signature.legacy_envelope_id
    assert_nil @signature.legacy_document_sha256
    assert_equal "Not their document", @signature.review_note
    assert_nil users(:one).reportable_nda_signature
    assert_predicate @import.reload, :rejected?
    assert_nothing_raised { create_legacy_signature(users(:two), legacy_envelope_id: envelope) }
  end

  test "refuses a decision it does not recognise" do
    patch :update, params: { id: @signature.id, decision: "maybe" }

    assert_predicate @signature.reload, :needs_review?
    assert_match(/approve or revoke/i, flash[:alert])
  end
end
