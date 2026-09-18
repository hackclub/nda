require "net/http"

class XaiDocumentReview
  ENDPOINT = URI("https://api.x.ai/v1/chat/completions")
  MAX_CHARS = 60_000
  PROMPT = <<~TEXT.freeze
    You are checking whether a document is the Hack Club Contributor NDA, a mutual non-disclosure
    agreement between the Hack Foundation and an individual contributor. The recipient's personal
    details have been removed before this text was sent to you.

    Answer only with JSON of the form:
    {"is_nda": true|false, "looks_altered": true|false, "concerns": ["short phrase", ...],
     "confidence": 0.0-1.0}

    Set looks_altered when clauses contradict each other, numbering is inconsistent, or wording
    looks spliced. Keep concerns short and factual. Report nothing about who signed it.
  TEXT

  Result = Data.define(:is_nda, :looks_altered, :concerns, :confidence) do
    def concerning? = !is_nda || looks_altered
  end

  class Error < StandardError; end

  class << self
    def enabled? = ENV["LEGACY_AI_REVIEW"].present? && ENV["XAI_API_KEY"].present?

    def call(text)
      request = Net::HTTP::Post.new(
        ENDPOINT,
        "Authorization" => "Bearer #{ENV.fetch("XAI_API_KEY")}",
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      )
      request.body = JSON.generate(
        model: ENV.fetch("XAI_REVIEW_MODEL", "grok-4-fast"),
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: PROMPT },
          { role: "user", content: text.to_s[0, MAX_CHARS] }
        ]
      )

      response = Net::HTTP.start(
        ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 5, read_timeout: 60
      ) { |http| http.request(request) }
      raise Error, "xAI returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      ZeroDataRetention.verify!(response)

      parse(response.body)
    rescue Timeout::Error, SocketError, SystemCallError, JSON::ParserError, KeyError, ZeroDataRetention::Error => error
      raise Error, error.message
    end

    private

    def parse(body)
      payload = JSON.parse(JSON.parse(body).dig("choices", 0, "message", "content").to_s)
      Result.new(
        is_nda: payload["is_nda"] == true,
        looks_altered: payload["looks_altered"] == true,
        concerns: Array(payload["concerns"]).map(&:to_s).first(10),
        confidence: payload["confidence"].to_f
      )
    end
  end
end
