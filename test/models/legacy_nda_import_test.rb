require "test_helper"

class LegacyNdaImportTest < ActiveSupport::TestCase
  def create_import(**overrides)
    users(:one).legacy_nda_imports.create!(**overrides)
  end

  test "starts out pending with no reasons recorded" do
    import = create_import

    assert_predicate import, :pending?
    assert_empty import.reasons
    assert_equal 0, import.challenge_attempts
  end

  test "a challenge is live only while it is unexpired and unexhausted" do
    import = create_import(challenge_digest: "digest", challenge_expires_at: 5.minutes.from_now)

    assert_predicate import, :challenge_live?

    import.challenge_expires_at = 1.minute.ago
    assert_not import.challenge_live?

    import.challenge_expires_at = 5.minutes.from_now
    import.challenge_attempts = LegacyNdaImport::MAX_CHALLENGE_ATTEMPTS
    assert_not import.challenge_live?
  end

  test "an absent challenge is never live" do
    assert_not create_import(challenge_expires_at: 5.minutes.from_now).challenge_live?
  end

  test "masks the challenge address without disclosing its length" do
    assert_equal "a•••@example.com", create_import(challenge_email: "ada@example.com").masked_challenge_email
    assert_equal "g•••@example.com", create_import(challenge_email: "grace@example.com").masked_challenge_email
    assert_equal "a•••@example.com", create_import(challenge_email: "a@example.com").masked_challenge_email
  end

  test "masks nothing when there is no address to mask" do
    assert_nil create_import(challenge_email: nil).masked_challenge_email
    assert_nil create_import(challenge_email: "not-an-address").masked_challenge_email
    assert_nil create_import(challenge_email: "@example.com").masked_challenge_email
  end
end
