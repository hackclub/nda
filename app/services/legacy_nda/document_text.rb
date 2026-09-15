require "pdf/reader"

module LegacyNda
  class DocumentText
    MAX_PAGES = 40
    CERTIFICATE_MARKER = /Envelope ID:/i
    UNMAPPED_GLYPHS = /[\u{E000}-\u{F8FF}]/

    Error = Class.new(CodedError)
    Result = Data.define(:pages, :body, :certificate_page)

    class << self
      def extract(bytes)
        reader = PDF::Reader.new(StringIO.new(bytes.b))
        raise Error, :too_many_pages if reader.page_count > MAX_PAGES

        pages = reader.pages.map { |page| normalize(page.text) }
        index = pages.rindex { |page| page.match?(CERTIFICATE_MARKER) }
        Result.new(
          pages: pages,
          body: (index ? pages[0...index] : pages).join("\n"),
          certificate_page: index ? pages[index] : ""
        )
      rescue PDF::Reader::EncryptedPDFError
        raise Error, :encrypted_pdf
      rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, ArgumentError
        raise Error, :unreadable_pdf
      end

      def normalize(text) = text.to_s.gsub(UNMAPPED_GLYPHS, " ")
    end
  end
end
