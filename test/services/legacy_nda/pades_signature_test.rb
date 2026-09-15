require "test_helper"
require_relative "../../support/legacy_pdf_factory"

class LegacyNda::PadesSignatureTest < ActiveSupport::TestCase
  def verify(pdf, allowlist: LegacyPdfFactory.allowlist)
    LegacyNda::PadesSignature.verify!(pdf, allowlist: allowlist)
  end

  def assert_rejected(code, pdf, allowlist: LegacyPdfFactory.allowlist)
    error = assert_raises(LegacyNda::PadesSignature::Error) { verify(pdf, allowlist: allowlist) }
    assert_equal code, error.code
  end

  test "verifies a signed document and reports the signing time and certificate" do
    result = verify(LegacyPdfFactory.signed_pdf)

    assert_in_delta Time.current, result.signing_time, 60
    assert_equal "ETSI.CAdES.detached", result.subfilter
    assert_equal LegacyNda::CertificateAllowlist.spki_sha256(LegacyPdfFactory.certificate), result.spki_sha256
    assert_includes result.certificate_subject, "Hack Club"
    assert_equal 0, result.byte_range.first
  end

  test "accepts a certificate that had already expired when it signed" do
    assert LegacyPdfFactory.certificate.not_after < Time.current, "fixture certificate should be expired"

    assert verify(LegacyPdfFactory.signed_pdf)
  end

  test "accepts the older adbe.pkcs7.detached subfilter" do
    assert_equal "adbe.pkcs7.detached", verify(LegacyPdfFactory.signed_pdf(subfilter: "adbe.pkcs7.detached")).subfilter
  end

  test "rejects a single flipped byte in the document body" do
    tampered = LegacyPdfFactory.tampered_pdf
    assert_equal LegacyPdfFactory.signed_pdf.bytesize, tampered.bytesize

    assert_rejected :signature_mismatch, tampered
  end

  test "rejects a signature made by an unpinned key" do
    rogue = LegacyPdfFactory.signed_pdf(
      key: LegacyPdfFactory.rogue_key, certificate: LegacyPdfFactory.rogue_certificate
    )

    assert_rejected :untrusted_certificate, rogue
  end

  test "accepts that same signature once its key is pinned" do
    rogue = LegacyPdfFactory.signed_pdf(
      key: LegacyPdfFactory.rogue_key, certificate: LegacyPdfFactory.rogue_certificate
    )

    assert verify(rogue, allowlist: LegacyPdfFactory.allowlist(LegacyPdfFactory.rogue_certificate))
  end

  test "rejects an incremental update appended after signing" do
    assert_rejected :byte_range_not_to_end, LegacyPdfFactory.appended_update_pdf
  end

  test "rejects a byte range that does not cover the whole file" do
    assert_rejected :byte_range_not_to_end, LegacyPdfFactory.short_byte_range_pdf
  end

  test "rejects a second signature appended to the file" do
    assert_rejected :multiple_signatures, LegacyPdfFactory.second_signature_pdf
  end

  test "rejects a decoy byte range planted in a content stream" do
    decoy = LegacyPdfFactory.signed_pdf(
      lines: LegacyPdfFactory::DEFAULT_LINES + [ "/ByteRange [ 0 99 99 0 ]" ]
    )

    assert_rejected :multiple_signatures, decoy
  end

  test "rejects a corrupt signature blob without raising" do
    assert_rejected :unparsable_signature, LegacyPdfFactory.corrupt_signature_pdf
  end

  test "rejects a document carrying no signature" do
    assert_rejected :missing_signature, "%PDF-1.7\nnothing signed here\n%%EOF\n"
  end

  test "rejects an unrecognised subfilter" do
    assert_rejected :unsupported_subfilter, LegacyPdfFactory.signed_pdf(subfilter: "adbe.x509.rsa_sha1")
  end

  test "rejects files that are not PDFs, are encrypted, or are oversize" do
    assert_rejected :not_a_pdf, "just some bytes"
    assert_rejected :encrypted_pdf, LegacyPdfFactory.signed_pdf.sub("/Type /Catalog", "/Encrypt 9 0 R")
    assert_rejected :too_large, "%PDF-1.7\n" + "x" * LegacyNda::PadesSignature::MAX_BYTES
  end
end
