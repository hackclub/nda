require "test_helper"

class LegacyNda::AirtableRecordTest < ActiveSupport::TestCase
  test "stops reading an Airtable attachment at the document size limit" do
    record = LegacyNda::AirtableRecord::Found.new(
      id: "recTest", email: "ada@example.com", name: "Ada", signed_at: Time.current,
      document_url: "https://files.airtableusercontent.com/nda.pdf", document_filename: "nda.pdf", document_bytes: 1
    )
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:read_body) do |&block|
      block.call("x" * LegacyNdaImport::MAX_DOCUMENT_BYTES)
      block.call("overflow")
    end
    http = Object.new
    http.define_singleton_method(:request) { |_, &block| block.call(response) }
    singleton = Net::HTTP.singleton_class
    original = singleton.instance_method(:start)
    singleton.define_method(:start) { |*, **, &block| block.call(http) }

    assert_nil LegacyNda::AirtableRecord.download(record)
  ensure
    singleton&.define_method(:start, original) if original
  end
end
