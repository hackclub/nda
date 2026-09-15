class VerifyLegacyNdaImportJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on LoopsClient::TransientError, wait: :polynomially_longer, attempts: 5

  def perform(import_id)
    import = LegacyNdaImport.includes(:user).find(import_id)
    return unless import.pending?

    import.update!(state: "verifying")
    result = LegacyNda::Verifier.call(SseCustomerBlob.download(import.document.blob), user: import.user)
    LegacyNda::Claim.apply!(import, result)
  rescue SseCustomerBlob::Error, ActiveStorage::FileNotFoundError => error
    Rails.logger.warn("Legacy NDA import #{import_id}: could not read the upload (#{error.class}).")
    import&.update!(state: "needs_review", reasons: import.reasons | [ "upload_unreadable" ])
  end
end
