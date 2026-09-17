require "test_helper"
require_relative "../../support/airtable_stub"

class Admin::NdaSignaturesControllerTest < ActionController::TestCase
  tests Admin::NdaSignaturesController
  include AirtableStub

  setup do
    @admin = users(:two)
    @admin.update!(admin: true)
    session[:user_id] = @admin.id
  end

  test "force approves a legacy signature and records an audit event" do
    signature = create_legacy_signature(users(:one), verification_state: "needs_review")
    legacy_import = users(:one).legacy_nda_imports.create!(state: "needs_review", nda_signature: signature)

    patch :update, params: { id: signature.id, reason: "Matched against internal records" }

    assert_predicate signature.reload, :approved?
    assert_predicate legacy_import.reload, :approved?
    action = AdminAction.order(:created_at).last
    assert_equal "force_approve", action.action
    assert_equal "Matched against internal records", action.reason
    assert_equal @admin, action.admin_user
  end

  test "does not force approve native signatures" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.update!(verification_state: "awaiting_cosigner")

    assert_no_difference("AdminAction.count") do
      patch :update, params: { id: signature.id, reason: "No" }
    end

    assert_predicate signature.reload, :awaiting_cosigner?
  end

  test "force approves a saved native recording and records the override" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.update!(verification_state: "rejected", validation_score: 0.64)

    assert_enqueued_with(job: SignatureCompletedJob, args: [ signature.id ]) do
      patch :update, params: { id: signature.id, reason: "Reviewed the saved recording" }
    end

    assert_predicate signature.reload, :approved?
    assert_equal @admin, signature.reviewed_by
    action = AdminAction.last
    assert_equal "force_sign", action.action
    assert_equal "0.64", action.details["validation_score"]
  end

  test "does not approve a saved native recording with no detected audio" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.update!(verification_state: "rejected", transcript: nil, validation_score: 0)

    assert_no_difference("AdminAction.count") do
      patch :update, params: { id: signature.id, reason: "Cannot hear it" }
    end

    assert_predicate signature.reload, :rejected?
    assert_match(/no detected audio/i, flash[:alert])
  end

  test "requires a reason before destroying a signature" do
    signature = create_legacy_signature(users(:one))

    assert_no_difference([ "NdaSignature.count", "AdminAction.count" ]) do
      delete :destroy, params: { id: signature.id }
    end
    assert_match(/reason is required/i, flash[:alert])
  end

  test "destroys a signature and linked import while retaining an audit snapshot" do
    signature = create_legacy_signature(users(:one), airtable_record_id: "rec123")
    users(:one).legacy_nda_imports.create!(state: "approved", nda_signature: signature)

    assert_difference("NdaSignature.count", -1) do
      assert_difference("LegacyNdaImport.count", -1) do
        assert_difference("AdminAction.count", 1) do
          delete :destroy, params: { id: signature.id, reason: "Duplicate record" }
        end
      end
    end

    action = AdminAction.last
    assert_equal signature.id, action.subject_id
    assert_equal "rec123", action.details["airtable_record_id"]
  end

  test "queues an Airtable sync for an approved signature" do
    signature = create_legacy_signature(users(:one))

    with_airtable do
      assert_enqueued_with(job: SyncSignatureToAirtableJob, args: [ signature.id ]) do
        post :sync, params: { id: signature.id }
      end
    end
    assert_equal "sync_airtable", AdminAction.last.action
  end
end
