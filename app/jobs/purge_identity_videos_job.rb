class PurgeIdentityVideosJob < ApplicationJob
  queue_as :default

  def perform
    expired = NdaSignature.identity_video_expired.to_a
    expired.each(&:purge_identity_video!)
    Rails.logger.info("Purged #{expired.size} identity video(s) past the retention window.")
    expired.size
  end
end
