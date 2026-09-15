require "test_helper"

class SlackClientTest < ActiveSupport::TestCase
  test "posts a plain-text message to Slack" do
    with_slack_response(body: { ok: true, ts: "123.456" }.to_json) do |requests|
      response = SlackClient.post_message(channel: "U0123ABCDE", text: "NDA processed")

      assert response["ok"]
      assert_equal 1, requests.size
      assert_equal "Bearer test-token", requests.first["Authorization"]
      assert_equal({
        "channel" => "U0123ABCDE", "text" => "NDA processed",
        "unfurl_links" => false, "unfurl_media" => false
      }, JSON.parse(requests.first.body))
    end
  end

  test "raises for a Slack API error without exposing the response body" do
    with_slack_response(body: { ok: false, error: "channel_not_found", detail: "private" }.to_json) do
      error = assert_raises(SlackClient::Error) do
        SlackClient.post_message(channel: "U0123ABCDE", text: "NDA processed")
      end

      assert_equal "Slack API error: channel_not_found", error.message
      refute_includes error.message, "private"
    end
  end

  test "marks server errors as transient" do
    with_slack_response(code: "503", body: "unavailable") do
      assert_raises(SlackClient::TransientError) do
        SlackClient.post_message(channel: "U0123ABCDE", text: "NDA processed")
      end
    end
  end

  private

  def with_slack_response(code: "200", body:)
    response = Net::HTTPResponse.send(:response_class, code).new("1.1", code, "")
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)

    singleton = Net::HTTP.singleton_class
    original = singleton.instance_method(:start)
    previous = ENV["SLACK_BOT_TOKEN"]
    ENV["SLACK_BOT_TOKEN"] = "test-token"
    requests = []
    singleton.define_method(:start) do |*, **, &http_block|
      http = Object.new
      http.define_singleton_method(:request) do |request|
        requests << request
        response
      end
      http_block.call(http)
    end
    yield requests
  ensure
    ENV["SLACK_BOT_TOKEN"] = previous
    singleton&.define_method(:start, original) if original
  end
end
