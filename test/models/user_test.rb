require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes Slack IDs" do
    user = User.new(hack_club_identity_id: "ident!new", slack_id: "uabc12345")
    user.validate
    assert_equal "UABC12345", user.slack_id
  end

  test "falls back to the Hack Club profile name in the signing form" do
    user = users(:one)
    assert_equal "Ada", user.default_legal_first_name
    assert_equal "Lovelace", user.default_legal_last_name

    user.legal_first_name = "Augusta"
    assert_equal "Augusta", user.default_legal_first_name
  end

  test "rejects a country outside the selectable list" do
    user = users(:one)
    user.assign_attributes(SIGNING_DETAILS.merge(country: "US"))
    assert_not user.valid?
    assert_includes user.errors[:country], "is not included in the list"
  end

  test "calculates age" do
    user = users(:one)
    user.birthdate = Date.new(2000, 1, 2)
    assert_equal 24, user.age(on: Date.new(2025, 1, 1))
    assert_equal 25, user.age(on: Date.new(2025, 1, 2))
  end

  test "reports an approved import when there is no native signature" do
    signature = create_legacy_signature(users(:one))

    assert_equal signature, users(:one).reportable_nda_signature
  end

  test "prefers the native signature when a member holds both" do
    create_legacy_signature(users(:one))
    native = create_signature(users(:one), signed_at: Time.current)

    assert_equal native, users(:one).reportable_nda_signature
    assert_predicate users(:one).reportable_nda_signature, :native?
  end

  test "does not report an import that is still awaiting review" do
    create_legacy_signature(users(:one), verification_state: "needs_review")

    assert_nil users(:one).reportable_nda_signature
  end

  test "does not report a revoked import" do
    create_legacy_signature(users(:one), verification_state: "rejected")

    assert_nil users(:one).reportable_nda_signature
  end

  test "reports the earliest import when a member somehow holds several" do
    older = create_legacy_signature(users(:one), signed_at: 3.years.ago)
    create_legacy_signature(users(:one), signed_at: 1.year.ago, document_version: "2024-01-01")

    assert_equal older, users(:one).reportable_nda_signature
  end
end
