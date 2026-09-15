require "test_helper"

class AirtableClientTest < ActiveSupport::TestCase
  test "quotes an address so it cannot break out of a formula" do
    assert_equal %("ada@example.com"), AirtableClient.quote("ada@example.com")
    assert_equal %("a\\"b"), AirtableClient.quote(%(a"b))
    assert_equal %("a\\\\b"), AirtableClient.quote("a\\b")
  end

  test "refuses to run without configuration" do
    assert_not AirtableClient.configured?
    assert_raises(AirtableClient::ConfigurationError) { AirtableClient.records(filter: "TRUE()") }
  end

  test "refuses an attachment Airtable would reject" do
    error = assert_raises(AirtableClient::Error) do
      AirtableClient.upload_attachment(
        "rec1", field: "Video", bytes: "0" * (AirtableClient::MAX_ATTACHMENT_BYTES + 1),
        filename: "big.webm", content_type: "video/webm"
      )
    end
    assert_match(/over Airtable's/, error.message)
  end
end
