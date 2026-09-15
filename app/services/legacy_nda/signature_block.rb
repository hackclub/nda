module LegacyNda
  class SignatureBlock
    HEADING = /^\s*AGREED\s*$/
    PRINTED_NAME = /^\s*Printed Name:\s*(.*)$/
    DATE = /^\s*Date:\s*(.*)$/
    ISO_DATE = /(\d{4})-(\d{2})-(\d{2})/
    NOT_A_VALUE = /\A\s*(?:[A-Za-z][\w '-]*:|\()/

    Result = Data.define(:recipient_name, :recipient_date, :cosigner_name, :cosigner_date) do
      def recipient_complete? = recipient_name.present? && recipient_date.present?
      def cosigner_present? = cosigner_name.present?
    end

    class << self
      def parse(body)
        lines = body.to_s.lines.map(&:rstrip)
        lines = lines.drop((lines.index { |line| line.match?(HEADING) } || 0))
        names = values(lines, PRINTED_NAME)
        dates = values(lines, DATE).map { |value| to_date(value) }

        Result.new(
          recipient_name: names.first, recipient_date: dates.first,
          cosigner_name: names.second, cosigner_date: dates.second
        )
      end

      private

      def values(lines, pattern)
        lines.each_with_index.filter_map do |line, index|
          next unless (match = line.match(pattern))

          match[1].strip.presence || continuation(lines[index + 1])
        end
      end

      def continuation(line)
        value = line.to_s.strip.presence
        value unless value.nil? || value.match?(NOT_A_VALUE)
      end

      def to_date(value)
        match = value.to_s.match(ISO_DATE) or return nil

        Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
      rescue Date::Error
        nil
      end
    end
  end
end
