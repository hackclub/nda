class LegacyNdaImport < ApplicationRecord
  CHALLENGE_TTL = 15.minutes
  MAX_CHALLENGE_ATTEMPTS = 5
  MAX_DOCUMENT_BYTES = 25.megabytes
  DOCUMENT_TYPES = %w[application/pdf].freeze

  belongs_to :user
  belongs_to :nda_signature, optional: true
  has_one_attached :document

  enum :state, {
    pending: "pending", verifying: "verifying", challenge_pending: "challenge_pending",
    approved: "approved", needs_review: "needs_review", rejected: "rejected"
  }, default: "pending", validate: true

  def purge_document!
    document.purge
    update!(document_purged_at: Time.current)
  end

  def challenge_live? = challenge_digest.present? && challenge_expires_at&.future? &&
    challenge_attempts < MAX_CHALLENGE_ATTEMPTS

  def masked_challenge_email
    local, domain = challenge_email.to_s.split("@", 2)
    return nil if local.blank? || domain.blank?

    "#{local.first}•••@#{domain}"
  end
end
