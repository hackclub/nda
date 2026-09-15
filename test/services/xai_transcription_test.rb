require "test_helper"

class XaiTranscriptionTest < ActiveSupport::TestCase
  setup do
    @video = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/pledge.webm"),
      "video/webm"
    )
  end

  test "returns the transcript without checking zero data retention" do
    with_response(zdr: "false") do
      assert_equal "I pledge.", XaiTranscription.call(@video)
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
