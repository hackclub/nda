require "test_helper"
require_relative "../support/airtable_stub"

class RefreshAirtableNdaCacheJobTest < ActiveJob::TestCase
  include AirtableStub

  SIGNED = {
    id: "recSigned", "Email": "Ada@Example.com", "Legal First Name": "Ada", "Legal Last Name": "Lovelace",
    "Signed?": true, "Loops - ndaCompletedAt": "2025-06-01T10:00:00.000Z"
  }.freeze
  UNSIGNED = { id: "recStarted", "Email": "grace@example.com", "Signed?": false }.freeze

  setup do
    AirtableNdaRecord.delete_all
    AirtableNdaBackfill.delete_all
  end

  test "caches every signed row and drops ones that are gone" do
    stale = SIGNED.merge(id: "recGone", "Email": "gone@example.com")
    with_airtable(rows: [ stale ]) { RefreshAirtableNdaCacheJob.perform_now }

    with_airtable(rows: [ SIGNED, UNSIGNED ]) { RefreshAirtableNdaCacheJob.perform_now }

    assert_equal [ "recSigned" ], AirtableNdaRecord.pluck(:airtable_record_id)
    assert_equal "recSigned", AirtableNdaRecord.signed_for("ada@example.com").id
    assert AirtableNdaRecord.backfill_complete?
  end

  test "keeps the cached copy when Airtable answers with nothing" do
    with_airtable(rows: [ SIGNED ]) { RefreshAirtableNdaCacheJob.perform_now }

    with_airtable(rows: []) { assert_nil RefreshAirtableNdaCacheJob.perform_now }

    assert_equal [ "recSigned" ], AirtableNdaRecord.pluck(:airtable_record_id)
  end

  test "does nothing when Airtable is not configured" do
    assert_nil RefreshAirtableNdaCacheJob.perform_now
    assert_not AirtableNdaRecord.backfill_complete?
  end
end
