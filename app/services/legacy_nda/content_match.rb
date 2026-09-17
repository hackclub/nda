module LegacyNda
  class ContentMatch
    MATCH_CONTAINMENT = 0.98
    MISMATCH_CONTAINMENT = 0.85
    MISMATCH_HEADINGS = 0.85
    HEADINGS = NdaDocument::SECTIONS.map(&:first).freeze

    Result = Data.define(:verdict, :containment, :jaccard, :headings_found, :headings_missing) do
      def match? = verdict == :match
      def mismatch? = verdict == :mismatch
      def heading_ratio = headings_found.fdiv(HEADINGS.size)
    end

    class << self
      def call(body)
        redacted = Redactor.call(body)
        expected = tokens(NdaDocument::LEGACY_TEXT)
        actual = tokens(redacted)
        shared = (expected & actual).size
        containment = shared.fdiv(expected.size)
        missing = HEADINGS.reject { |heading| heading_present?(redacted, heading) }
        found = HEADINGS.size - missing.size

        Result.new(
          verdict: verdict(containment, found),
          containment: containment.round(4),
          jaccard: shared.fdiv((expected | actual).size).round(4),
          headings_found: found,
          headings_missing: missing
        )
      end

      private

      def verdict(containment, headings_found)
        ratio = headings_found.fdiv(HEADINGS.size)
        return :mismatch if containment < MISMATCH_CONTAINMENT || ratio < MISMATCH_HEADINGS
        return :match if containment >= MATCH_CONTAINMENT && headings_found == HEADINGS.size

        :uncertain
      end

      # Headings survive extraction with their numbering but not always their spacing.
      def heading_present?(text, heading)
        text.downcase.gsub(/\s+/, " ").include?(heading.downcase.gsub(/\s+/, " "))
      end

      def tokens(text) = text.to_s.downcase.scan(/[a-z0-9]+/).to_set
    end
  end
end
