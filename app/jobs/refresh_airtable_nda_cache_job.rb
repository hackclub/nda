class RefreshAirtableNdaCacheJob < ApplicationJob
  queue_as :default

  # A failed page raises before anything is replaced, but an empty answer would wipe every cached
  # signature, so it is treated as a fault in the base rather than as nobody having signed.
  def perform
    return unless AirtableClient.configured?

    records = LegacyNda::AirtableRecord.all_signed.to_a
    if records.empty?
      Rails.logger.warn("Airtable returned no signed NDAs; keeping the cached copy.")
      return
    end

    AirtableNdaRecord.replace_from_airtable!(records)
  end
end
