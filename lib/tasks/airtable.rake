namespace :airtable do
  desc "Tag rows the old signing system wrote, so Source means something on every record"
  task backfill_source: :environment do
    rows = AirtableClient.records(filter: %(AND({Signed?}, {Source} = "")), fields: [ "Email" ], max_records: 100)
    abort "Nothing to backfill." if rows.empty?

    updated = AirtableClient.update_many(rows.map { |row| [ row["id"], { "Source" => "old system" } ] })
    puts "Tagged #{updated} rows. Run again until it reports nothing to backfill."
  end
end
