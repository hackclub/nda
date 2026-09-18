require "test_helper"

class ImportAirtableNdaJobTest < ActiveJob::TestCase
  test "a transient Airtable failure returns the import to pending before retry" do
    import = users(:one).legacy_nda_imports.create!(source: "airtable")
    singleton = LegacyNda::AirtableImport.singleton_class
    original = singleton.instance_method(:claim!)
    singleton.define_method(:claim!) { |_| raise AirtableClient::TransientError, "temporary outage" }

    assert_enqueued_with(job: ImportAirtableNdaJob, args: [ import.id ]) do
      ImportAirtableNdaJob.perform_now(import.id)
    end

    assert_predicate import.reload, :pending?
  ensure
    singleton&.define_method(:claim!, original) if original
  end

  test "a retry can continue an import already marked as verifying" do
    import = users(:one).legacy_nda_imports.create!(source: "airtable", state: "verifying")
    called = false
    singleton = LegacyNda::AirtableImport.singleton_class
    original = singleton.instance_method(:claim!)
    singleton.define_method(:claim!) { |_| called = true }

    ImportAirtableNdaJob.perform_now(import.id)

    assert called
  ensure
    singleton&.define_method(:claim!, original) if original
  end
end
