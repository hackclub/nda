require "test_helper"

class CosignatureTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @signature = minor_signature
  end

  def minor_signature
    @user.update!(SIGNING_DETAILS.merge(birthdate: 15.years.ago.to_date))
    signature = @user.nda_signatures.build(
      document_version: NdaDocument::VERSION, document_sha256: NdaDocument.sha256,
      signed_name: "Ada Lovelace", signed_at: Time.current, transcript: "I pledge.",
      cosigner_name: "Byron Lovelace", cosigner_email: "parent@example.com",
      verification_state: "awaiting_cosigner"
    )
    signature.identity_video.attach(
      io: file_fixture("pledge.webm").open, filename: "pledge.webm", content_type: "video/webm"
    )
    signature.save!
    signature
  end

  def invite_token
    mail = with_stubbed_mail { Cosignature.invite!(@signature) } && sent_mail_for(:cosign_request).last
    mail[:data_variables]["cosign_url"].split("/cosign/").last
  end

  test "a minor's signature does not count until the guardian signs" do
    assert_predicate @signature, :awaiting_cosigner?
    assert_nil @user.reload.reportable_nda_signature
  end

  test "countersigning approves the signature and records who signed" do
    token = invite_token
    Cosignature.countersign!(
      Cosignature.find(token), token: token, name: " Byron  Lovelace ", ip: "192.0.2.9"
    )

    @signature.reload
    assert_predicate @signature, :approved?
    assert_equal "Byron Lovelace", @signature.cosigner_signed_name
    assert_equal "192.0.2.9", @signature.cosigner_ip_address
    assert_equal @signature, @user.reload.reportable_nda_signature
  end

  test "the token never reaches the database in the clear" do
    token = invite_token

    assert token.present?
    assert_not_includes @signature.reload.cosigner_token_digest, token
    assert_equal 64, @signature.cosigner_token_digest.length
  end

  test "a wrong, expired or spent token finds nothing" do
    token = invite_token

    assert_nil Cosignature.find("not-a-real-token")
    assert_nil Cosignature.find(nil)

    @signature.update!(cosigner_token_expires_at: 1.minute.ago)
    assert_nil Cosignature.find(token), "an expired link is dead"

    @signature.update!(cosigner_token_expires_at: 1.day.from_now)
    Cosignature.countersign!(@signature, token: token, name: "Byron Lovelace")
    assert_nil Cosignature.find(token), "a used link is dead"
  end

  test "re-inviting invalidates the previous link" do
    first = invite_token
    second = invite_token

    assert_not_equal first, second
    assert_nil Cosignature.find(first)
    assert_equal @signature, Cosignature.find(second)
  end

  test "a guardian cannot countersign twice" do
    token = invite_token
    Cosignature.countersign!(@signature, token: token, name: "Byron Lovelace")

    assert_raises(Cosignature::AlreadySigned) do
      Cosignature.countersign!(@signature, token: token, name: "Someone Else")
    end
    assert_raises(Cosignature::AlreadySigned) { Cosignature.invite!(@signature) }
  end

  test "only one request can consume a token" do
    token = invite_token
    first_request = Cosignature.find(token)
    overlapping_request = Cosignature.find(token)

    assert_enqueued_jobs 1, only: SignatureCompletedJob do
      Cosignature.countersign!(first_request, token: token, name: "Byron Lovelace")
    end
    assert_raises(Cosignature::AlreadySigned) do
      Cosignature.countersign!(overlapping_request, token: token, name: "Someone Else")
    end

    @signature.reload
    assert_equal "Byron Lovelace", @signature.cosigner_signed_name
    assert_equal 1, enqueued_jobs.count { _1[:job] == SignatureCompletedJob }
  end

  test "the invitation names the teen and carries a link, never their address or video" do
    with_stubbed_mail { Cosignature.invite!(@signature) }
    mail = sent_mail_for(:cosign_request).sole

    assert_equal "parent@example.com", mail[:to]
    assert_equal "Ada Lovelace", mail[:data_variables]["signer_fullName"]
    assert_includes mail[:data_variables]["cosign_url"], "/cosign/"
    assert_empty mail[:data_variables].values_at(*%w[address birthdate transcript identityVideo]).compact
  end

  test "an adult is never asked for a co-signature" do
    signature = create_signature(users(:two), signed_at: Time.current)

    assert_not_predicate signature, :requires_cosignature?
    assert_predicate signature, :approved?
  end
end
