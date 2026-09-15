require "test_helper"

class LegacyNda::CertificatePageTest < ActiveSupport::TestCase
  PAGE = <<~TEXT
       Automation                           N/A                                   Sent: 2026 06 14 08 00 48 AM UTC
                                                                                  Viewed: Unknown
       Cc                                                                         Signed: Unknown

       Ada Lovelace                                                               Sent: 2026 06 14 08 00 49 AM UTC
       ada@example.com
                                                                                  Viewed: 2026 06 14 09 10 10 AM UTC
       Signer
                                                                                  Signed: 2026 06 14 10 14 50 AM UTC
       Authentication Level:                                                      Reason: I am a signer of this document
                                            Signature ID
       Email                                CMQDHVSTC016GMH4OA0QUOZU2

                                            IP Address: 172.70.1.2

       Grace Hopper                                                               Sent: 2026 06 14 10 14 52 AM UTC

       grace@example.com                                               Viewed: 2026 06 14 10 18 07 AM UTC

       Signer                                                                     Signed: 2026 06 14 10 19 16 AM UTC

       Authentication Level:                Signature ID                         Reason: I am a signer of this document
       Email                                CMQDHVSTC016LMH4OSYQPLLOA

    Envelope ID: envelope_lhecmvlheriakemt
  TEXT

  setup { @page = LegacyNda::CertificatePage.parse(PAGE) }

  test "extracts the envelope id" do
    assert_equal "envelope_lhecmvlheriakemt", @page.envelope_id
  end

  test "extracts every recipient including non-signers" do
    assert_equal 3, @page.signers.size
    assert_equal %w[Cc Signer Signer], @page.signers.map(&:role)
    assert_equal "Automation", @page.signers.first.name
  end

  test "identifies the recipient and the cosigner among the signers" do
    assert_equal "Ada Lovelace", @page.recipient.name
    assert_equal "ada@example.com", @page.recipient.email
    assert_equal "CMQDHVSTC016GMH4OA0QUOZU2", @page.recipient.signature_id
    assert_equal "Grace Hopper", @page.cosigner.name
    assert_equal "grace@example.com", @page.cosigner.email
  end

  test "parses the signing timestamps as UTC" do
    assert_equal Time.utc(2026, 6, 14, 10, 14, 50), @page.recipient.signed_at
    assert_equal Time.utc(2026, 6, 14, 9, 10, 10), @page.recipient.viewed_at
    assert_equal Time.utc(2026, 6, 14, 8, 0, 49), @page.recipient.sent_at
    assert_equal Time.utc(2026, 6, 14, 10, 19, 16), @page.cosigner.signed_at
  end

  test "leaves unknown timestamps nil rather than guessing" do
    assert_nil @page.signers.first.signed_at
    assert_nil @page.signers.first.viewed_at
  end

  test "reads timestamps that kept their separators" do
    assert_equal Time.utc(2026, 6, 14, 13, 5, 7),
      LegacyNda::CertificatePage.parse_time("2026-06-14 01:05:07 PM UTC")
    assert_equal Time.utc(2026, 6, 14, 0, 5, 7),
      LegacyNda::CertificatePage.parse_time("2026-06-14 12:05:07 AM UTC")
    assert_equal Time.utc(2026, 6, 14, 12, 5, 7),
      LegacyNda::CertificatePage.parse_time("2026-06-14 12:05:07 PM UTC")
  end

  test "yields nothing from a page it cannot make sense of" do
    page = LegacyNda::CertificatePage.parse("this page is not a signing certificate at all")

    assert_nil page.envelope_id
    assert_empty page.signers
    assert_nil page.recipient
    assert_nil page.cosigner
  end

  test "yields nothing from empty input" do
    assert_empty LegacyNda::CertificatePage.parse(nil).signers
    assert_empty LegacyNda::CertificatePage.parse("").signers
  end
end
