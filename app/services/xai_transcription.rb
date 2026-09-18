require "net/http/post/multipart"

class XaiTranscription
  ENDPOINT = URI("https://api.x.ai/v1/stt")

  class Error < StandardError; end

  def self.call(uploaded_file)
    api_key = ENV["XAI_API_KEY"]
    raise Error, "XAI_API_KEY is not configured" if api_key.blank?

    file = UploadIO.new(uploaded_file.tempfile, uploaded_file.content_type, uploaded_file.original_filename)
    request = Net::HTTP::Post::Multipart.new(
      ENDPOINT.path,
      { "model" => "grok-voice-transcribe-2.0", "format" => "true", "language" => "en", "keyterm" => "Hack Club", "file" => file },
      "Authorization" => "Bearer #{api_key}"
    )
    response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 10, read_timeout: 90) do |http|
      http.request(request)
    end
    raise Error, "xAI returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).fetch("text")
  rescue KeyError, JSON::ParserError, Timeout::Error, SocketError, SystemCallError => error
    raise Error, error.message
  end
end
