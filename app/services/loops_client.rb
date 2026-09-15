require "net/http"

# TODO: just a stub for now, but eventually this will be a full client for Loops txn emails
class LoopsClient
  ENDPOINT = URI("https://app.loops.so/api/v1/transactional")

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TransientError < Error; end

  class << self
    def configured? = ENV["LOOPS_API_KEY"].present?

    def send_email(to:, transactional_id:, data_variables: {})
      raise ConfigurationError, "LOOPS_API_KEY is not configured" unless configured?
      raise ConfigurationError, "No Loops transactional id was given" if transactional_id.blank?

      request = Net::HTTP::Post.new(
        ENDPOINT,
        "Authorization" => "Bearer #{ENV.fetch("LOOPS_API_KEY")}",
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      )
      request.body = JSON.generate(transactionalId: transactional_id, email: to, dataVariables: data_variables)

      response = Net::HTTP.start(
        ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 5, read_timeout: 10
      ) { |http| http.request(request) }
      parse_response(response)
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise TransientError, "Loops is unavailable: #{error.message}"
    end

    private

    def parse_response(response)
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      code = response.code.to_i
      error_class = code == 429 || code >= 500 ? TransientError : Error
      raise error_class, "Loops returned HTTP #{response.code}"
    rescue JSON::ParserError
      raise TransientError, "Loops returned an invalid response"
    end
  end
end
