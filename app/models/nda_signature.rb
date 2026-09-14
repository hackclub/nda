class NdaSignature < ApplicationRecord
  IDENTITY_VIDEO_RETENTION = 7.days
  VIDEO_TYPES = %w[video/mp4 video/webm].freeze
  MAX_VIDEO_BYTES = 25.megabytes

  belongs_to :user
  has_one_attached :identity_video

  scope :identity_video_expired, -> {
    where(identity_video_purged_at: nil).where(signed_at: ...IDENTITY_VIDEO_RETENTION.ago)
  }

  validates :document_version, :document_sha256, :signed_name, :signed_at, :transcript, presence: true
  validates :document_version, uniqueness: { scope: :user_id }
  validates :document_sha256, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :signed_name, length: { maximum: 200 }
  validate :acceptable_identity_video
  validate :cosigner_present_for_minor
  validate :signed_name_matches_recipient

  def purge_identity_video!
    identity_video.purge
    update!(identity_video_purged_at: Time.current)
  end

  private

  def acceptable_identity_video
    return if identity_video_purged_at?
    return errors.add(:identity_video, "is required") unless identity_video.attached?

    errors.add(:identity_video, "must be an MP4 or WebM video") unless identity_video.content_type.in?(VIDEO_TYPES)
    errors.add(:identity_video, "must be 25 MB or smaller") if identity_video.byte_size > MAX_VIDEO_BYTES
  end

  def cosigner_present_for_minor
    return unless user&.age && user.age < 18

    errors.add(:cosigner_name, "is required for recipients under 18") if cosigner_name.blank?
    errors.add(:cosigner_email, "is required for recipients under 18") if cosigner_email.blank?
  end

  def signed_name_matches_recipient
    return if signed_name.to_s.squish.casecmp?(user&.legal_name.to_s)

    errors.add(:signed_name, "must match the recipient's legal name")
  end
end
