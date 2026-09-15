require "digest"

module LegacyNda
  class CertificateAllowlist
    CONFIG_PATH = "config/legacy_signing_certificates.yml".freeze
    ENV_KEY = "LEGACY_SIGNING_CERTIFICATE_SPKI_SHA256".freeze

    Pin = Data.define(:name, :spki_sha256, :certificate_sha256)

    class << self
      attr_writer :default

      def default = @default ||= new(from_config + from_env)

      def reset! = @default = nil

      def spki_sha256(certificate) = Digest::SHA256.hexdigest(certificate.public_key.to_der)

      def certificate_sha256(certificate) = Digest::SHA256.hexdigest(certificate.to_der)

      private

      def from_config
        path = Rails.root.join(CONFIG_PATH)
        return [] unless path.exist?

        Array(YAML.safe_load_file(path)).map do |entry|
          Pin.new(
            name: entry["name"].to_s,
            spki_sha256: entry["spki_sha256"].to_s.downcase.presence,
            certificate_sha256: entry["certificate_sha256"].to_s.downcase.presence
          )
        end
      end

      def from_env
        ENV[ENV_KEY].to_s.split(",").filter_map do |digest|
          digest = digest.strip.downcase
          Pin.new(name: "#{ENV_KEY} entry", spki_sha256: digest, certificate_sha256: nil) if digest.present?
        end
      end
    end

    attr_reader :pins

    def initialize(pins)
      @pins = Array(pins).freeze
    end

    def include?(certificate) = pin_for(certificate).present?

    def pin_for(certificate)
      spki = self.class.spki_sha256(certificate)
      whole = self.class.certificate_sha256(certificate)
      pins.find do |pin|
        (pin.spki_sha256.present? && secure_compare(pin.spki_sha256, spki)) ||
          (pin.certificate_sha256.present? && secure_compare(pin.certificate_sha256, whole))
      end
    end

    private

    def secure_compare(expected, actual) = ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end
end
