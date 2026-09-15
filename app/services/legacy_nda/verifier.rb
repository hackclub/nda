require "digest"

module LegacyNda
  class Verifier
    VERSION = 1
    DATE_TOLERANCE = 1

    Result = Data.define(:verdict, :reasons, :fields) do
      def approved? = verdict == :approved
      def needs_review? = verdict == :needs_review
      def rejected? = verdict == :rejected
    end

    class << self
      def call(bytes, user:, allowlist: CertificateAllowlist.default)
        signature = PadesSignature.verify!(bytes, allowlist: allowlist)
        text = DocumentText.extract(bytes)
        page = CertificatePage.parse(text.certificate_page)
        block = SignatureBlock.parse(text.body)
        content = ContentMatch.call(text.body)

        return reject(:content_mismatch) if content.mismatch?

        flags = flags(signature, page, block, content, user)
        review = ai_review(text.body)
        flags << :ai_review_concern if review&.concerning?
        Result.new(
          verdict: flags.empty? ? :approved : :needs_review,
          reasons: flags,
          fields: fields(bytes, signature, page, block, content).merge(ai_fields(review))
        )
      rescue CodedError => error
        reject(error.code)
      end

      private

      def reject(code) = Result.new(verdict: :rejected, reasons: [ code ], fields: {})

      def ai_review(body)
        return nil unless XaiDocumentReview.enabled?

        XaiDocumentReview.call(Redactor.call(body))
      rescue XaiDocumentReview::Error => error
        Rails.logger.warn("Legacy NDA AI review unavailable: #{error.message}")
        nil
      end

      def ai_fields(review) = { ai_review: review&.to_h }

      def flags(signature, page, block, content, user)
        [].tap do |flags|
          flags << :content_uncertain unless content.match?
          flags << :no_certificate_page if page.recipient.nil? || page.recipient.email.blank?
          flags << :envelope_id_missing if page.envelope_id.blank?
          flags << :signature_block_incomplete unless block.recipient_complete?
          flags << :body_date_disagrees unless dates_agree?(signature.signing_time, block.recipient_date)
          flags << :printed_name_differs unless names_agree?(user, recipient_name(page, block))
        end
      end

      def recipient_name(page, block) = page.recipient&.name.presence || block.recipient_name

      def dates_agree?(signing_time, body_date)
        return true if body_date.nil?

        (signing_time.to_date - body_date).abs <= DATE_TOLERANCE
      end

      def names_agree?(user, printed_name)
        return true if user.legal_name.blank? || printed_name.blank?

        normalize(user.legal_name) == normalize(printed_name)
      end

      def normalize(name) = name.to_s.downcase.gsub(/[^a-z0-9]/, "")

      def fields(bytes, signature, page, block, content)
        {
          verifier_version: VERSION,
          signed_at: (signature.signing_time || page.recipient&.signed_at)&.iso8601,
          cms_signing_time: signature.signing_time&.iso8601,
          certificate_page_signed_at: page.recipient&.signed_at&.iso8601,
          body_date: block.recipient_date&.iso8601,
          document_sha256: Digest::SHA256.hexdigest(bytes),
          envelope_id: page.envelope_id,
          certificate_spki_sha256: signature.spki_sha256,
          certificate_sha256: signature.certificate_sha256,
          certificate_subject: signature.certificate_subject,
          subfilter: signature.subfilter,
          signer_name: recipient_name(page, block),
          signer_email: page.recipient&.email,
          cosigner_present: page.cosigner.present? || block.cosigner_present?,
          cosigner_signed_at: page.cosigner&.signed_at&.iso8601,
          content_containment: content.containment,
          content_jaccard: content.jaccard,
          content_headings_found: content.headings_found,
          content_headings_missing: content.headings_missing,
          content_thresholds: {
            match_containment: ContentMatch::MATCH_CONTAINMENT,
            mismatch_containment: ContentMatch::MISMATCH_CONTAINMENT
          }
        }
      end
    end
  end
end
