require "test_helper"

class LoopsClientTest < ActiveSupport::TestCase
  test "posts the documented transactional payload" do
    request = nil
    response = http_response("200", { success: true }.to_json)

    with_http_response(response, capture: ->(value) { request = value }) do
      with_env("LOOPS_API_KEY" => "test-key") do
        result = LoopsClient.send_email(
          to: "recipient@example.com",
          transactional_id: "template-id",
          data_variables: { challenge_code: "123456" }
        )
        assert_equal true, result["success"]
      end
    end

    assert_equal "Bearer test-key", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]
    assert_equal({
      "transactionalId" => "template-id",
      "email" => "recipient@example.com",
      "dataVariables" => { "challenge_code" => "123456" }
    }, JSON.parse(request.body))
  end

  test "treats rate limits as transient" do
    with_http_response(http_response("429", "{}")) do
      with_env("LOOPS_API_KEY" => "test-key") do
        assert_raises(LoopsClient::TransientError) do
          LoopsClient.send_email(to: "recipient@example.com", transactional_id: "template-id")
        end
      end
    end
  end

  test "rejects missing configuration" do
    assert_raises(LoopsClient::ConfigurationError) do
      LoopsClient.send_email(to: "recipient@example.com", transactional_id: "template-id")
    end
  end

  test "lifts a suppression before sending" do
    requests = []
    responses = [
      http_response("200", { isSuppressed: true }.to_json),
      http_response("200", { success: true }.to_json)
    ]

    with_http_response(responses, capture: ->(value) { requests << value }) do
      with_env("LOOPS_API_KEY" => "test-key") do
        assert LoopsClient.lift_suppression("parent+nda@example.com")
      end
    end

    assert_equal %w[GET DELETE], requests.map(&:method)
    assert_equal "/api/v1/contacts/suppression?email=parent%2Bnda%40example.com", requests.last.path
    assert_equal "Bearer test-key", requests.last["Authorization"]
  end

  test "leaves an address that is not suppressed alone" do
    requests = []
    with_http_response(http_response("200", { isSuppressed: false }.to_json), capture: ->(value) { requests << value }) do
      with_env("LOOPS_API_KEY" => "test-key") do
        refute LoopsClient.lift_suppression("parent@example.com")
      end
    end

    assert_equal %w[GET], requests.map(&:method)
  end

  test "treats an unknown contact as not suppressed" do
    with_http_response(http_response("404", { success: false }.to_json)) do
      with_env("LOOPS_API_KEY" => "test-key") do
        refute LoopsClient.lift_suppression("stranger@example.com")
      end
    end
  end

  private

  def http_response(code, body)
    Net::HTTPResponse.send(:response_class, code).new("1.1", code, "").tap do |response|
      response.instance_variable_set(:@body, body)
      response.instance_variable_set(:@read, true)
    end
  end

  def with_http_response(responses, capture: nil)
    queue = Array(responses)
    singleton = Net::HTTP.singleton_class
    original = singleton.instance_method(:start)
    singleton.define_method(:start) do |*, **, &block|
      client = Object.new
      client.define_singleton_method(:request) do |request|
        capture&.call(request)
        queue.size > 1 ? queue.shift : queue.first
      end
      block.call(client)
    end
    yield
  ensure
    singleton.define_method(:start, original)
  end

  def with_env(values)
    previous = values.to_h { |key, _| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
