class AttachAirtableDocumentJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on AirtableClient::TransientError, wait: :polynomially_longer, attempts: 5

  def perform(import_id)
    import = LegacyNdaImport.find(import_id)
    return if import.airtable_record_id.blank? || import.document.attached?

    LegacyNda::AirtableImport.archive_document!(import, LegacyNda::AirtableRecord.find(import.airtable_record_id))
  end
end
