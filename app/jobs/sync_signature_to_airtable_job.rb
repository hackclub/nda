class SyncSignatureToAirtableJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on AirtableClient::TransientError, wait: :polynomially_longer, attempts: 5

  def perform(signature_id)
    AirtableSync.call(NdaSignature.includes(:user).find(signature_id))
  end
end
