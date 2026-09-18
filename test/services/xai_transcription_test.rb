require "test_helper"

class XaiTranscriptionTest < ActiveSupport::TestCase
  setup do
    @video = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/pledge.webm"),
      "video/webm"
    )
  end

  test "returns the transcript when zero data retention is confirmed" do
    with_response(zdr: "true") do
      assert_equal "I pledge.", XaiTranscription.call(@video)
    end
  end

  test "returns the transcript when the voice endpoint omits the zero data retention header" do
    with_response(zdr: nil) do
      assert_equal "I pledge.", XaiTranscription.call(@video)
    end
  end

  test "rejects a transcript when zero data retention is not confirmed" do
    with_response(zdr: "false") do
      error = assert_raises(XaiTranscription::Error) { XaiTranscription.call(@video) }
      assert_match(/did not confirm zero data retention/, error.message)
    end
  end

  test "reports an error response" do
    with_response(zdr: nil, code: "500", body: "boom") do
      error = assert_raises(XaiTranscription::Error) { XaiTranscription.call(@video) }
      assert_equal "xAI returned HTTP 500", error.message
    end
  end

  private

  def with_response(zdr:, code: "200", body: { text: "I pledge." }.to_json)
    response = Net::HTTPResponse.send(:response_class, code).new("1.1", code, "")
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response["x-zero-data-retention"] = zdr if zdr

    singleton = Net::HTTP.singleton_class
    original = singleton.instance_method(:start)
    singleton.define_method(:start) { |*, **| response }

    with_env("XAI_API_KEY", "test-key") { yield }
  ensure
    singleton.define_method(:start, original) if original
  end

  def with_env(key, value)
    previous = ENV[key]
    ENV[key] = value
    yield
  ensure
    ENV[key] = previous
  end
end
