require "net/http"

class LoopsClient
  ENDPOINT = URI("https://app.loops.so/api/v1/transactional")

  TEMPLATES = {
    import_challenge: "LOOPS_IMPORT_CHALLENGE_TRANSACTIONAL_ID",
    import_settled: "LOOPS_IMPORT_SETTLED_TRANSACTIONAL_ID",
    import_rejected: "LOOPS_IMPORT_REJECTED_TRANSACTIONAL_ID",
    import_needs_review: "LOOPS_IMPORT_NEEDS_REVIEW_TRANSACTIONAL_ID",
    signature_receipt: "LOOPS_SIGNATURE_RECEIPT_TRANSACTIONAL_ID",
    cosign_request: "LOOPS_COSIGN_REQUEST_TRANSACTIONAL_ID",
    cosign_receipt: "LOOPS_COSIGN_RECEIPT_TRANSACTIONAL_ID"
  }.freeze

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TransientError < Error; end

  class << self
    def configured? = ENV["LOOPS_API_KEY"].present?

    def template_id(template) = ENV[TEMPLATES.fetch(template.to_sym)].presence

    def deliverable?(template) = configured? && template_id(template).present?

    def deliver(template, to:, data: {})
      send_email(to: to, transactional_id: template_id(template), data_variables: data)
    end

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
