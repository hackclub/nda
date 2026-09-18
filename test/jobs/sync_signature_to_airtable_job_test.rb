require "test_helper"

class SyncSignatureToAirtableJobTest < ActiveJob::TestCase
  setup do
    @signature = create_signature(users(:one), signed_at: Time.current)
    @singleton = AirtableSync.singleton_class
    @original = @singleton.instance_method(:call)
  end

  teardown { @singleton.define_method(:call, @original) }

  test "records a permanent failure for the admin dashboard" do
    @singleton.define_method(:call) { |_| raise AirtableClient::Error, "Airtable returned HTTP 422: invalid field" }

    assert_raises(AirtableClient::Error) { SyncSignatureToAirtableJob.perform_now(@signature.id) }

    @signature.reload
    assert_equal 1, @signature.airtable_sync_attempts
    assert_equal "Airtable returned HTTP 422: invalid field", @signature.airtable_sync_error
    assert @signature.airtable_sync_failed_at?
  end

  test "does not sync a signature that was revoked while queued" do
    @signature.update!(verification_state: "rejected")
    called = false
    @singleton.define_method(:call) { |_| called = true }

    SyncSignatureToAirtableJob.perform_now(@signature.id)

    assert_not called
    assert_equal 0, @signature.reload.airtable_sync_attempts
  end
end
