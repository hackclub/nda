require "test_helper"

class PurgeIdentityVideosJobTest < ActiveJob::TestCase
  test "purges only videos past the retention window" do
    fresh = create_signature(users(:one), signed_at: 1.day.ago)
    stale = create_signature(users(:two), signed_at: (NdaSignature::IDENTITY_VIDEO_RETENTION + 1.day).ago)

    assert_equal 1, PurgeIdentityVideosJob.perform_now

    assert_not stale.reload.identity_video.attached?
    assert_predicate fresh.reload.identity_video, :attached?
    assert_equal 0, PurgeIdentityVideosJob.perform_now
  end
end
