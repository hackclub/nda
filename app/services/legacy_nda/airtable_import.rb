require "digest"

module LegacyNda
  class AirtableImport
    class << self
      def claim!(import)
        record = AirtableRecord.signed_for(import.user.email)
        return settle!(import, record) if record && !taken?(record)

        import.update!(state: "email_pending")
      end

      def check_on_sign_in(user, ip: nil)
        return nil if user.email.blank? || user.reportable_nda_signature

        cached = AirtableNdaRecord.signed_for(user.email)
        if user.airtable_checked_at?
          return nil if cached.nil? || taken?(cached)

          return settle!(user.legacy_nda_imports.create!(source: "airtable", ip_address: ip), cached)
        end

        record = cached || AirtableRecord.signed_for(user.email)
        user.update!(airtable_checked_at: Time.current)
        return nil if record.nil? || taken?(record)

        settle!(user.legacy_nda_imports.create!(source: "airtable", ip_address: ip), record)
      end

      def challenge!(import, email)
        address = email.to_s.strip
        record = AirtableRecord.signed_for(address)
        return EmailChallenge.issue!(import, email: record.email) if record && !taken?(record)

        import.update!(state: "challenge_pending", challenge_email: address, challenge_digest: nil)
      end

      def settle_challenge!(import)
        record = AirtableRecord.signed_for(import.challenge_email)
        return Claim.reject!(import, "airtable_row_missing") unless record
        return Claim.reject!(import, "already_claimed") if taken?(record)

        settle!(import, record)
      end

      def archive_document!(import, record)
        bytes = AirtableRecord.download(record)
        return if bytes.blank?

        import.document.attach(
          io: StringIO.new(bytes), filename: record.document_filename, content_type: "application/pdf"
        )
        digest = Digest::SHA256.hexdigest(bytes)
        import.update!(document_sha256: digest)
        import.nda_signature&.update!(document_sha256: digest, legacy_document_sha256: digest)
      rescue ActiveRecord::RecordNotUnique
        Rails.logger.warn("Legacy NDA import #{import.id}: that document already belongs to another signature.")
      end

      private

      def settle!(import, record)
        import.update!(airtable_record_id: record.id)
        signature = import.user.nda_signatures.create!(attributes_for(import, record))
        import.update!(state: "approved", nda_signature: signature)
        ImportMailer.settled(import)
        AttachAirtableDocumentJob.perform_later(import.id)
        SyncSignatureToAirtableJob.perform_later(signature.id) if AirtableClient.configured?
        import
      rescue ActiveRecord::RecordNotUnique
        Claim.reject!(import, "already_claimed")
      end

      def attributes_for(import, record)
        {
          signature_type: "legacy",
          legacy_source: "airtable",
          verification_state: "approved",
          document_version: NdaDocument::LEGACY_VERSION,
          legacy_signer_name: record.name,
          legacy_signer_email: record.email,
          legacy_verification: { "source" => "airtable", "airtable_record_id" => record.id },
          airtable_record_id: record.id,
          signed_name: record.name,
          signed_at: record.signed_at,
          ip_address: import.ip_address
        }
      end

      def taken?(record)
        NdaSignature.where.not(verification_state: "rejected").exists?(airtable_record_id: record.id)
      end
    end
  end
end
