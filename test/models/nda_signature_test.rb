require "test_helper"

class NdaSignatureTest < ActiveSupport::TestCase
  test "a video deleted by hand leaves the signature valid" do
    signature = create_signature(users(:one), signed_at: 8.days.ago)

    assert_difference -> { ActiveStorage::Blob.count }, -1 do
      signature.purge_identity_video!
    end

    assert_not signature.reload.identity_video.attached?
    assert_not_nil signature.identity_video_purged_at
    assert_predicate signature, :valid?
  end

  test "a signature defaults to the in-app flow" do
    assert_predicate create_signature(users(:one), signed_at: Time.current), :native?
    assert_predicate create_signature(users(:two), signed_at: Time.current), :approved?
  end

  test "an imported signature needs no video, transcript or legal name match" do
    signature = create_legacy_signature(users(:one), signed_name: "A Name That Matches Nothing")

    assert_predicate signature, :legacy?
    assert_predicate signature, :valid?
    assert_nil signature.transcript
    assert_not signature.identity_video.attached?
  end

  test "an import records the document digest and the certificate it was trusted under" do
    signature = create_legacy_signature(users(:one))

    signature.legacy_document_sha256 = nil
    assert_not signature.valid?
    assert_includes signature.errors[:legacy_document_sha256], "can't be blank"

    signature = create_legacy_signature(users(:two))
    signature.legacy_signing_certificate_fingerprint = nil
    assert_not signature.valid?
  end

  test "an import without an envelope id is still valid" do
    signature = create_legacy_signature(users(:one), legacy_envelope_id: nil)

    assert_predicate signature, :valid?
    assert_nothing_raised { create_legacy_signature(users(:two), legacy_envelope_id: nil) }
  end

  test "a revoked import releases its envelope so the owner can claim it" do
    signature = create_legacy_signature(users(:one))
    signature.update!(verification_state: "rejected", legacy_envelope_id: nil, legacy_document_sha256: nil)

    assert_predicate signature, :rejected?
    assert_nothing_raised { create_legacy_signature(users(:two)) }
  end

  test "an envelope can only be claimed once" do
    envelope = create_legacy_signature(users(:one)).legacy_envelope_id

    assert_raises(ActiveRecord::RecordNotUnique) do
      create_legacy_signature(users(:two), legacy_envelope_id: envelope)
    end
  end

  test "a document can only be claimed once" do
    digest = create_legacy_signature(users(:one)).legacy_document_sha256

    assert_raises(ActiveRecord::RecordNotUnique) do
      create_legacy_signature(users(:two), legacy_document_sha256: digest)
    end
  end

  test "a member may hold both an imported and a native signature" do
    create_legacy_signature(users(:one))

    assert_nothing_raised { create_signature(users(:one), signed_at: Time.current) }
    assert_equal 2, users(:one).nda_signatures.count
  end

  test "rejects identity videos outside MP4 and WebM" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.identity_video.attach(io: StringIO.new("not a video"), filename: "pledge.mov", content_type: "video/quicktime")

    assert_not signature.valid?
    assert_includes signature.errors[:identity_video], "must be an MP4 or WebM video"
  end
end
