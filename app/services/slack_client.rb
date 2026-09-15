require "net/http"

class SlackClient
  ENDPOINT = URI("https://slack.com/api/chat.postMessage")
  TRANSIENT_API_ERRORS = %w[fatal_error internal_error rate_limited service_unavailable].freeze

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TransientError < Error; end

  class << self
    def configured?
      ENV["SLACK_BOT_TOKEN"].present?
    end

    def post_message(channel:, text:)
      raise ConfigurationError, "SLACK_BOT_TOKEN is not configured" unless configured?

      request = Net::HTTP::Post.new(
        ENDPOINT,
        "Authorization" => "Bearer #{ENV.fetch("SLACK_BOT_TOKEN")}",
        "Content-Type" => "application/json; charset=utf-8",
        "Accept" => "application/json"
      )
      request.body = JSON.generate(channel: channel, text: text, unfurl_links: false, unfurl_media: false)

      response = Net::HTTP.start(
        ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 5, read_timeout: 10
      ) { |http| http.request(request) }
      parse_response(response)
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise TransientError, "Slack is unavailable: #{error.message}"
    end

    private

    def parse_response(response)
      unless response.is_a?(Net::HTTPSuccess)
        error_class = response.code.to_i == 429 || response.code.to_i >= 500 ? TransientError : Error
        raise error_class, "Slack returned HTTP #{response.code}"
      end

      payload = JSON.parse(response.body)
      return payload if payload["ok"]

      error = payload.fetch("error", "unknown_error")
      error_class = error.in?(TRANSIENT_API_ERRORS) ? TransientError : Error
      raise error_class, "Slack API error: #{error}"
    rescue JSON::ParserError
      raise TransientError, "Slack returned an invalid response"
    end
  end
end
