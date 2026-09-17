require "test_helper"
require_relative "../support/airtable_stub"

class AirtableNdaRecordTest < ActiveSupport::TestCase
  include AirtableStub

  setup do
    AirtableNdaRecord.delete_all
    AirtableNdaBackfill.delete_all
  end

  test "backfill keeps signed rows and normalizes their email addresses" do
    signed = {
      id: "recSigned", "Email": " Ada@Example.com ", "Legal First Name": "Ada",
      "Legal Last Name": "Lovelace", "Signed?": true,
      "Loops - ndaCompletedAt": "2025-06-01T10:00:00.000Z"
    }
    unsigned = signed.merge(id: "recUnsigned", "Email": "other@example.com", "Signed?": false,
      "Loops - ndaCompletedAt": nil)

    records = nil
    with_airtable(rows: [ signed, unsigned ]) { records = LegacyNda::AirtableRecord.all_signed.to_a }
    assert_equal 1, AirtableNdaRecord.replace_from_airtable!(records)

    cached = AirtableNdaRecord.signed_for("ADA@example.COM")
    assert_equal "recSigned", cached.id
    assert_equal "Ada Lovelace", cached.name
    assert AirtableNdaRecord.backfill_complete?
  end

  test "a rerun removes rows no longer signed in Airtable" do
    old = LegacyNda::AirtableRecord::Found.new(
      id: "recOld", email: "old@example.com", name: "Old Name", signed_at: Time.current,
      document_url: nil, document_filename: nil, document_bytes: nil
    )
    AirtableNdaRecord.replace_from_airtable!([ old ])

    AirtableNdaRecord.replace_from_airtable!([])

    assert_empty AirtableNdaRecord.all
    assert AirtableNdaRecord.backfill_complete?
  end
end
