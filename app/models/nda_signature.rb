class NdaSignature < ApplicationRecord
  VIDEO_TYPES = %w[video/mp4 video/webm].freeze
  MAX_VIDEO_BYTES = 25.megabytes

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_one :legacy_nda_import, dependent: :nullify
  has_one_attached :identity_video

  enum :signature_type, { native: "native", legacy: "legacy" }, default: "native", validate: true
  enum :verification_state, {
    approved: "approved", awaiting_cosigner: "awaiting_cosigner", needs_review: "needs_review",
    rejected: "rejected"
  }, default: "approved", validate: true
  enum :legacy_source, { upload: "upload", airtable: "airtable" }, prefix: true, validate: { allow_nil: true }

  validates :document_version, :signed_name, :signed_at, presence: true
  validates :document_version, uniqueness: { scope: :user_id }
  validates :document_sha256, presence: true, unless: :legacy_source_airtable?
  validates :document_sha256, format: { with: /\A[0-9a-f]{64}\z/ }, allow_nil: true
  validates :signed_name, length: { maximum: 200 }
  validates :cosigner_signed_name, length: { maximum: 200 }, allow_nil: true

  with_options if: :native? do
    validates :transcript, presence: true
    validate :acceptable_identity_video
    validate :cosigner_present_for_minor
    validate :signed_name_matches_recipient
  end

  with_options if: -> { legacy? && !rejected? && !legacy_source_airtable? } do
    validates :legacy_signing_certificate_fingerprint, presence: true
    validates :legacy_document_sha256, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  end

  def requires_cosignature? = native? && cosigner_email.present? && user&.age.to_i < 18

  def cosigned? = cosigner_signed_at.present?

  def cosignature_pending? = requires_cosignature? && !cosigned?

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
