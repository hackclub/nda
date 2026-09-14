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
  end
end
