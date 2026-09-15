module LegacyNda
  class CertificatePage
    ROLES = %w[Signer Cc Viewer Approver Assistant].freeze
    ENVELOPE_ID = /Envelope ID:\s*(\S+)/i
    SIGNER_HEADER = /^[ \t]*(?<name>\S.*?)[ \t]{2,}Sent:[ \t]*(?<sent>.+?)[ \t]*$/
    ROLE = /^[ \t]*(#{ROLES.join("|")})\b/
    EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/
    SIGNATURE_ID = /\b([A-Z0-9]{16,})\b/
    TIMESTAMP = /(\d{4})[-\s]?(\d{2})[-\s]?(\d{2})\s+(\d{1,2})[:\s]?(\d{2})[:\s]?(\d{2})\s*(AM|PM)?/i

    Result = Data.define(:envelope_id, :signers) do
      def signers_only = signers.select(&:signer?)
      def recipient = signers_only.first
      def cosigner = signers_only.second
    end

    Signer = Data.define(:name, :email, :role, :signature_id, :sent_at, :viewed_at, :signed_at) do
      def signer? = role == "Signer"
    end

    class << self
      def parse(text)
        text = text.to_s
        lines = text.lines
        headers = lines.each_with_index.filter_map { |line, index| (m = line.match(SIGNER_HEADER)) && [ index, m ] }
        signers = headers.each_with_index.map do |(index, match), position|
          signer(match, lines[index...(headers.dig(position + 1, 0) || lines.length)].join)
        end
        Result.new(envelope_id: text[ENVELOPE_ID, 1], signers: signers)
      end

      def parse_time(value)
        match = value.to_s.match(TIMESTAMP) or return nil

        year, month, day, hour, minute, second = match.captures.first(6).map(&:to_i)
        hour = hour % 12 + (match[7].to_s.casecmp?("PM") ? 12 : 0) if match[7]
        Time.utc(year, month, day, hour, minute, second)
      rescue ArgumentError
        nil
      end

      private

      def signer(match, block)
        Signer.new(
          name: match[:name].split(/\s{2,}/).first&.squish.presence,
          email: block[EMAIL]&.downcase,
          role: block[ROLE, 1],
          signature_id: block.split("Signature ID", 2).last&.[](SIGNATURE_ID, 1),
          sent_at: parse_time(match[:sent]),
          viewed_at: parse_time(block[/^.*\bViewed:(.*)$/, 1]),
          signed_at: parse_time(block[/^.*\bSigned:(.*)$/, 1])
        )
      end
    end
  end
end
