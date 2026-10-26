require "net/http"

class LoopsClient
  ENDPOINT = URI("https://app.loops.so/api/v1/transactional")
  SUPPRESSION_ENDPOINT = URI("https://app.loops.so/api/v1/contacts/suppression")

  TEMPLATES = {
    import_challenge: "LOOPS_IMPORT_CHALLENGE_TRANSACTIONAL_ID",
    import_settled: "LOOPS_IMPORT_SETTLED_TRANSACTIONAL_ID",
    import_rejected: "LOOPS_IMPORT_REJECTED_TRANSACTIONAL_ID",
    import_needs_review: "LOOPS_IMPORT_NEEDS_REVIEW_TRANSACTIONAL_ID",
    signature_receipt: "LOOPS_SIGNATURE_RECEIPT_TRANSACTIONAL_ID",
    cosign_request: "LOOPS_COSIGN_REQUEST_TRANSACTIONAL_ID",
    cosign_receipt: "LOOPS_COSIGN_RECEIPT_TRANSACTIONAL_ID"
  }.freeze

  SEND_DESPITE_SUPPRESSION = %i[cosign_request].freeze

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TransientError < Error; end

  class << self
    def configured? = ENV["LOOPS_API_KEY"].present?

    def template_id(template) = ENV[TEMPLATES.fetch(template.to_sym)].presence

    def deliverable?(template) = configured? && template_id(template).present?

    def deliver(template, to:, data: {})
      lift_suppression(to) if SEND_DESPITE_SUPPRESSION.include?(template.to_sym)
      send_email(to: to, transactional_id: template_id(template), data_variables: data)
    end

    def send_email(to:, transactional_id:, data_variables: {})
      raise ConfigurationError, "LOOPS_API_KEY is not configured" unless configured?
      raise ConfigurationError, "No Loops transactional id was given" if transactional_id.blank?

      request = Net::HTTP::Post.new(ENDPOINT, headers.merge("Content-Type" => "application/json"))
      request.body = JSON.generate(transactionalId: transactional_id, email: to, dataVariables: data_variables)
      parse_response(perform(request))
    end

    def lift_suppression(email)
      raise ConfigurationError, "LOOPS_API_KEY is not configured" unless configured?

      uri = SUPPRESSION_ENDPOINT.dup.tap { |value| value.query = URI.encode_www_form(email: email) }
      response = perform(Net::HTTP::Get.new(uri, headers))
      return false if response.is_a?(Net::HTTPNotFound) || !parse_response(response)["isSuppressed"]

      parse_response(perform(Net::HTTP::Delete.new(uri, headers)))
      true
    end

    private

    def headers = { "Authorization" => "Bearer #{ENV.fetch("LOOPS_API_KEY")}", "Accept" => "application/json" }

    def perform(request)
      Net::HTTP.start(
        request.uri.host, request.uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10
      ) { |http| http.request(request) }
    rescue Timeout::Error, SocketError, SystemCallError, EOFError, OpenSSL::SSL::SSLError => error
      raise TransientError, "Loops is unavailable: #{error.class}"
    end

    def parse_response(response)
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      code = response.code.to_i
      error_class = code == 408 || code == 429 || code >= 500 ? TransientError : Error
      raise error_class, "Loops returned HTTP #{response.code}"
    rescue JSON::ParserError
      raise TransientError, "Loops returned an invalid response"
    end
  end
end
