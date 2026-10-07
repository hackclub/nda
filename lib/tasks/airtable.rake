namespace :airtable do
  desc "Cache every signed legacy NDA locally so sign-in does not have to wait on Airtable"
  task backfill_ndas: :environment do
    abort "Airtable is not configured." unless AirtableClient.configured?

    cached = RefreshAirtableNdaCacheJob.perform_now
    abort "Airtable returned no signed NDAs; the cache was left alone." unless cached
    puts "Cached #{cached} signed Airtable NDA records. Login lookups are now local."
  end

  desc "Tag rows the old signing system wrote, so Source means something on every record"
  task backfill_source: :environment do
    rows = AirtableClient.records(filter: %(AND({Signed?}, {Source} = "")), fields: [ "Email" ], max_records: 100)
    abort "Nothing to backfill." if rows.empty?

    updated = AirtableClient.update_many(rows.map { |row| [ row["id"], { "Source" => "old system" } ] })
    puts "Tagged #{updated} rows. Run again until it reports nothing to backfill."
  end
end
