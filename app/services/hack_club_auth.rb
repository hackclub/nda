require "net/http"

class HackClubAuth
  BASE_URL = "https://auth.hackclub.com"
  SCOPES = %w[openid profile email name slack_id].freeze

  class Error < StandardError; end

  class << self
    def authorization_url(state:)
      uri = URI("#{BASE_URL}/oauth/authorize")
      uri.query = URI.encode_www_form(
        client_id: client_id,
        redirect_uri: callback_url,
        response_type: "code",
        scope: SCOPES.join(" "),
        state: state
      )
      uri.to_s
    end

    def identity_for(code)
      token = post_json("/oauth/token", {
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: callback_url,
        code: code,
        grant_type: "authorization_code"
      }).fetch("access_token")

      get_json("/api/v1/me", token: token).fetch("identity")
    rescue KeyError, JSON::ParserError => error
      raise Error, "Unexpected response from Hack Club Auth: #{error.message}"
    end

    private

    def client_id = ENV.fetch("HACK_CLUB_CLIENT_ID")
    def client_secret = ENV.fetch("HACK_CLUB_CLIENT_SECRET")
    def callback_url = ENV.fetch("HACK_CLUB_REDIRECT_URI", "http://localhost:3000/auth/hack_club/callback")

    def post_json(path, body)
      request = Net::HTTP::Post.new(path, "Content-Type" => "application/json", "Accept" => "application/json")
      request.body = JSON.generate(body)
      perform(request)
    end

    def get_json(path, token:)
      request = Net::HTTP::Get.new(path, "Authorization" => "Bearer #{token}", "Accept" => "application/json")
      perform(request)
    end

    def perform(request)
      uri = URI(BASE_URL)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end
      raise Error, "Hack Club Auth returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise Error, "Hack Club Auth is unavailable: #{error.message}"
    end
  end
end
