module AppHost
  DEFAULT = "https://nda.hackclub.com".freeze
  def self.origin = ENV["APP_HOST"].presence&.chomp("/") || DEFAULT
  def self.url_for(path) = "#{origin}#{path}"
end
