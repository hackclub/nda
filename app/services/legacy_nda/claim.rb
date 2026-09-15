module LegacyNda
  class Claim
    class << self
      def apply!(import, result)
        import.assign_attributes(
          verification: result.fields.deep_stringify_keys.merge("verdict" => result.verdict.to_s),
          reasons: result.reasons.map(&:to_s),
          document_sha256: result.fields[:document_sha256],
          envelope_id: result.fields[:envelope_id]
        )
        return reject!(import) if result.rejected?
        return reject!(import, "already_claimed") if already_claimed?(import)
        return challenge!(import) if challengeable?(import)

        settle!(import)
      end

      def settle!(import)
        signature = import.user.nda_signatures.create!(attributes_for(import))
        import.update!(state: signature.verification_state, nda_signature: signature)
        import
      rescue ActiveRecord::RecordNotUnique
        reject!(import, "already_claimed")
      end

      def reject!(import, reason = nil)
        import.reasons |= [ reason ].compact
        import.update!(state: "rejected")
        if reason == "already_claimed"
          Rails.logger.warn("Legacy NDA import #{import.id}: user #{import.user_id} claimed a held envelope.")
        end
        import
      end

      private

      def attributes_for(import)
        fields = import.verification
        {
          signature_type: "legacy",
          verification_state: verdict_for(import),
          document_version: NdaDocument::LEGACY_VERSION,
          document_sha256: fields["document_sha256"],
          legacy_document_sha256: fields["document_sha256"],
          legacy_envelope_id: fields["envelope_id"],
          legacy_signing_certificate_fingerprint: fields["certificate_spki_sha256"],
          legacy_signer_name: fields["signer_name"],
          legacy_signer_email: fields["signer_email"],
          legacy_cosigner_present: fields["cosigner_present"],
          legacy_cosigner_signed_at: fields["cosigner_signed_at"],
          legacy_verification: fields.merge("reasons" => import.reasons),
          signed_name: fields["signer_name"],
          signed_at: fields["signed_at"],
          ip_address: import.ip_address
        }
      end

      def verdict_for(import)
        return "needs_review" if import.verification["signer_email"].blank?

        import.verification["verdict"]
      end

      def challengeable?(import)
        import.verification["signer_email"].present? && !account_email_matches?(import)
      end

      def already_claimed?(import)
        claimed = NdaSignature.legacy.where.not(verification_state: "rejected")
        by_digest = claimed.where(legacy_document_sha256: import.document_sha256)
        return by_digest.exists? if import.envelope_id.blank?

        by_digest.or(claimed.where(legacy_envelope_id: import.envelope_id)).exists?
      end

      def account_email_matches?(import)
        account = import.user.email.to_s.strip.downcase
        account.present? && account == import.verification["signer_email"].to_s.strip.downcase
      end

      def challenge!(import)
        EmailChallenge.issue!(import, email: import.verification["signer_email"])
      end
    end
  end
end
