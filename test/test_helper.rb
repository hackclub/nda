ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    SIGNING_DETAILS = {
      legal_first_name: "Ada", legal_last_name: "Lovelace", email: "ada@example.com",
      birthdate: Date.new(1990, 1, 1), address_line_1: "15 Falls Rd", city: "Shelburne",
      region: "VT", postal_code: "05482", country: "United States"
    }.freeze

    def create_signature(user, signed_at:)
      user.update!(SIGNING_DETAILS)
      user.nda_signatures.build(
        document_version: NdaDocument::VERSION, document_sha256: NdaDocument.sha256,
        signed_name: "Ada Lovelace", signed_at: signed_at, transcript: "I pledge."
      ).tap do |signature|
        signature.identity_video.attach(
          io: file_fixture("pledge.webm").open, filename: "pledge.webm", content_type: "video/webm"
        )
        signature.save!
      end
    end

    def create_legacy_signature(user, signed_at: 1.year.ago, **overrides)
      digest = overrides[:legacy_document_sha256] || SecureRandom.hex(32)
      user.nda_signatures.create!({
        signature_type: "legacy",
        document_version: NdaDocument::LEGACY_VERSION,
        document_sha256: digest,
        legacy_document_sha256: digest,
        legacy_envelope_id: "envelope_#{SecureRandom.hex(8)}",
        legacy_signing_certificate_fingerprint: SecureRandom.hex(32),
        legacy_signer_name: "Ada Lovelace",
        legacy_signer_email: "ada@example.com",
        signed_name: "Ada Lovelace",
        signed_at: signed_at
      }.merge(overrides))
    end
  end
end
