require "test_helper"

class NdaSignatureTest < ActiveSupport::TestCase
  test "only signatures past the retention window are expired" do
    fresh = create_signature(users(:one), signed_at: 1.day.ago)
    stale = create_signature(users(:two), signed_at: (NdaSignature::IDENTITY_VIDEO_RETENTION + 1.day).ago)

    assert_equal [ stale ], NdaSignature.identity_video_expired.to_a
    assert_predicate fresh.identity_video, :attached?
  end

  test "purging deletes the video and keeps the signature" do
    signature = create_signature(users(:one), signed_at: 8.days.ago)

    assert_difference -> { ActiveStorage::Blob.count }, -1 do
      signature.purge_identity_video!
    end

    assert_not signature.reload.identity_video.attached?
    assert_not_nil signature.identity_video_purged_at
    assert_predicate signature, :valid?
    assert_empty NdaSignature.identity_video_expired
  end

  test "rejects identity videos outside MP4 and WebM" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.identity_video.attach(io: StringIO.new("not a video"), filename: "pledge.mov", content_type: "video/quicktime")

    assert_not signature.valid?
    assert_includes signature.errors[:identity_video], "must be an MP4 or WebM video"
  end
end
