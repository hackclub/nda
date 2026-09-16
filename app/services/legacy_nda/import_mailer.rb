module LegacyNda
  class ImportMailer
    class << self
      def settled(import)
        signature = import.nda_signature
        return unless signature

        deliver(import, :import_settled, {
          nda_signedOn: signature.signed_at&.to_date&.to_fs(:long),
          nda_version: signature.document_version
        })
      end

      def needs_review(import) = deliver(import, :import_needs_review)

      def rejected(import) = deliver(import, :import_rejected)

      private

      def deliver(import, template, extra = {})
        SendEmailJob.deliver_later(
          template,
          to: import.user.email,
          data: { signer_fullName: import.user.display_name, nda_importUrl: AppHost.url_for("/legacy_nda_import") }.merge(extra)
        )
      end
    end
  end
end
