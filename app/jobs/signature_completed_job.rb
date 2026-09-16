class SignatureCompletedJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(signature_id)
    signature = NdaSignature.includes(:user).find(signature_id)
    return unless signature.approved?

    NotifyNdaSignedJob.perform_later(signature.id) if SlackClient.configured?
    SyncSignatureToAirtableJob.perform_later(signature.id) if AirtableClient.configured?
    deliver_receipts(signature)
  end

  private

  def deliver_receipts(signature)
    SendEmailJob.deliver_later(
      :signature_receipt,
      to: signature.user.email,
      data: {
        signer_fullName: signature.user.legal_name,
        nda_signedOn: signature.signed_at.to_date.to_fs(:long),
        nda_version: signature.document_version,
        nda_agreementUrl: AppHost.url_for("/nda_signature")
      }
    )
    return unless signature.cosigned?

    SendEmailJob.deliver_later(
      :cosign_receipt,
      to: signature.cosigner_email,
      data: {
        cosigner_name: signature.cosigner_signed_name,
        signer_fullName: signature.user.legal_name,
        nda_signedOn: signature.cosigner_signed_at.to_date.to_fs(:long),
        nda_version: signature.document_version
      }
    )
  end
end
