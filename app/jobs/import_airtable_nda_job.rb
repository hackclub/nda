class ImportAirtableNdaJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on AirtableClient::TransientError, LoopsClient::TransientError, wait: :polynomially_longer, attempts: 5

  def perform(import_id, fresh: false)
    import = LegacyNdaImport.includes(:user).find(import_id)
    return unless import.pending? || import.verifying?

    import.update!(state: "verifying") if import.pending?
    LegacyNda::AirtableImport.claim!(import, fresh:)
  rescue AirtableClient::TransientError
    import.update!(state: "pending") if import&.verifying?
    raise
  end
end
