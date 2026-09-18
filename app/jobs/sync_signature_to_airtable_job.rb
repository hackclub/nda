class SyncSignatureToAirtableJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on AirtableClient::TransientError, wait: :polynomially_longer, attempts: 5

  def perform(signature_id)
    signature = NdaSignature.includes(:user).find(signature_id)
    return unless signature.approved?

    signature.update!(
      airtable_sync_attempts: signature.airtable_sync_attempts + 1,
      airtable_sync_error: nil,
      airtable_sync_failed_at: nil
    )
    AirtableSync.call(signature)
  rescue AirtableClient::Error => error
    signature&.update!(airtable_sync_error: error.message.to_s.first(240), airtable_sync_failed_at: Time.current)
    raise
  end
end
