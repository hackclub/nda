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

  private

  def http_response(code, body)
    Net::HTTPResponse.send(:response_class, code).new("1.1", code, "").tap do |response|
      response.instance_variable_set(:@body, body)
      response.instance_variable_set(:@read, true)
    end
  end

  def with_http_response(response, capture: nil)
    singleton = Net::HTTP.singleton_class
    original = singleton.instance_method(:start)
    singleton.define_method(:start) do |*, **, &block|
      client = Object.new
      client.define_singleton_method(:request) { |request| capture&.call(request); response }
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
