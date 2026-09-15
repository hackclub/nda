require "test_helper"
require_relative "../../support/legacy_pdf_factory"

class LegacyNda::CertificateAllowlistTest < ActiveSupport::TestCase
  HACK_CLUB_SPKI = "6a3845598e6f66f8c2919ce7473a0665aa56495a468e38eb42a1c97ce68feacf".freeze

  def with_env(value)
    ENV[LegacyNda::CertificateAllowlist::ENV_KEY] = value
    LegacyNda::CertificateAllowlist.reset!
    yield
  ensure
    ENV.delete(LegacyNda::CertificateAllowlist::ENV_KEY)
    LegacyNda::CertificateAllowlist.reset!
  end

  test "pins the known Hack Club signing certificate from config" do
    assert LegacyNda::CertificateAllowlist.default.pins.any? { |pin| pin.spki_sha256 == HACK_CLUB_SPKI },
      "config/legacy_signing_certificates.yml must keep pinning every certificate that signed a real NDA"
  end

  test "matches on the public key digest alone" do
    assert LegacyPdfFactory.allowlist.include?(LegacyPdfFactory.certificate)
  end

  test "matches on the whole certificate digest alone" do
    certificate = LegacyPdfFactory.certificate
    allowlist = LegacyNda::CertificateAllowlist.new([
      LegacyNda::CertificateAllowlist::Pin.new(
        name: "exact", spki_sha256: nil,
        certificate_sha256: LegacyNda::CertificateAllowlist.certificate_sha256(certificate)
      )
    ])

    assert allowlist.include?(certificate)
  end

  test "excludes a certificate it has never been told about" do
    assert_not LegacyPdfFactory.allowlist.include?(LegacyPdfFactory.rogue_certificate)
    assert_not LegacyNda::CertificateAllowlist.new([]).include?(LegacyPdfFactory.certificate)
  end

  test "reads additional pins from the environment" do
    certificate = LegacyPdfFactory.rogue_certificate

    with_env(" #{LegacyNda::CertificateAllowlist.spki_sha256(certificate).upcase} ") do
      assert LegacyNda::CertificateAllowlist.default.include?(certificate)
    end
    assert_not LegacyNda::CertificateAllowlist.default.include?(certificate)
  end
end
