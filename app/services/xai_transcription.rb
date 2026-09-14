require "net/http/post/multipart"

class XaiTranscription
  ENDPOINT = URI("https://api.x.ai/v1/stt")
  # https://docs.x.ai/developers/faq/security#how-to-check-that-zdr-is-enabled
  ZDR_HEADER = "x-zero-data-retention".freeze

  class Error < StandardError; end
  class RetentionError < Error; end

  def self.call(uploaded_file)
    api_key = ENV["XAI_API_KEY"]
    raise Error, "XAI_API_KEY is not configured" if api_key.blank?

    file = UploadIO.new(uploaded_file.tempfile, uploaded_file.content_type, uploaded_file.original_filename)
    request = Net::HTTP::Post::Multipart.new(
      ENDPOINT.path,
      { "format" => "true", "language" => "en", "keyterm" => "Hack Club", "file" => file },
      "Authorization" => "Bearer #{api_key}"
    )
    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 10, read_timeout: 90) do |http|
      http.request(request)
    end
    enforce_zero_data_retention!(response)
    raise Error, "xAI returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("text")
  rescue KeyError, JSON::ParserError, Timeout::Error, SocketError, SystemCallError => error
    raise Error, error.message
  end

  def self.enforce_zero_data_retention!(response)
    zdr = response[ZDR_HEADER].to_s.strip
    return if zdr.blank? || zdr.casecmp?("true")

    raise RetentionError, "xAI reports that zero data retention is disabled; transcription rejected."
  end
  private_class_method :enforce_zero_data_retention!
end
