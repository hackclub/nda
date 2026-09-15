require "test_helper"
require_relative "../../support/legacy_pdf_factory"

class LegacyNda::DocumentTextTest < ActiveSupport::TestCase
  test "extracts the text of every page" do
    pdf = LegacyPdfFactory.signed_pdf(pages: [ [ "First page" ], [ "Second page" ] ])
    text = LegacyNda::DocumentText.extract(pdf)

    assert_equal 2, text.pages.size
    assert_includes text.pages.first, "First page"
    assert_includes text.pages.second, "Second page"
  end

  test "splits the body from the signing certificate page" do
    pdf = LegacyPdfFactory.signed_pdf(pages: [
      [ "AGREED", "Printed Name: Ada Lovelace" ],
      [ "Envelope ID: envelope_abc123" ]
    ])
    text = LegacyNda::DocumentText.extract(pdf)

    assert_includes text.body, "Ada Lovelace"
    assert_not_includes text.body, "Envelope ID"
    assert_includes text.certificate_page, "envelope_abc123"
  end

  test "keeps every page as body when there is no certificate page" do
    pdf = LegacyPdfFactory.signed_pdf(pages: [ [ "Clause text" ], [ "AGREED", "Printed Name: Ada Lovelace" ] ])
    text = LegacyNda::DocumentText.extract(pdf)

    assert_empty text.certificate_page
    assert_includes text.body, "Clause text"
    assert_includes text.body, "AGREED"
    assert_includes text.body, "Ada Lovelace"
  end

  test "replaces unmapped glyphs with spaces so word boundaries survive" do
    assert_equal "2026 06 14 10 14 50 AM",
      LegacyNda::DocumentText.normalize("20260614 101450 AM")
    assert_equal "plain text", LegacyNda::DocumentText.normalize("plain text")
  end

  test "refuses a document with an implausible number of pages" do
    pdf = LegacyPdfFactory.signed_pdf(pages: Array.new(LegacyNda::DocumentText::MAX_PAGES + 1) { [ "x" ] })
    error = assert_raises(LegacyNda::DocumentText::Error) { LegacyNda::DocumentText.extract(pdf) }

    assert_equal :too_many_pages, error.code
  end

  test "refuses bytes it cannot read as a PDF" do
    error = assert_raises(LegacyNda::DocumentText::Error) { LegacyNda::DocumentText.extract("not a pdf") }

    assert_equal :unreadable_pdf, error.code
  end
end
