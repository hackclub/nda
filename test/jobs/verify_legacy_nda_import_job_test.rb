require "test_helper"
require_relative "../support/legacy_pdf_factory"

class VerifyLegacyNdaImportJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @user.update!(email: "ada@example.com")
    LegacyNda::CertificateAllowlist.default = LegacyPdfFactory.allowlist
  end

  teardown { LegacyNda::CertificateAllowlist.reset! }

  def import_for(pdf, user: @user)
    user.legacy_nda_imports.create!(ip_address: "192.0.2.1").tap do |import|
      import.document.attach(io: StringIO.new(pdf), filename: "nda.pdf", content_type: "application/pdf")
    end
  end

  def verify_import(pdf, user: @user)
    import = import_for(pdf, user: user)
    with_stubbed_mail { VerifyLegacyNdaImportJob.perform_now(import.id) }
    import.reload
  end

  test "approves a document signed from the member's own account email" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "ada@example.com"))

    assert_predicate import, :approved?
    assert_empty sent_mail_for(:import_challenge), "no challenge is needed when the account email already matches"

    signature = import.nda_signature
    assert_equal "legacy", signature.signature_type
    assert_equal NdaDocument::LEGACY_VERSION, signature.document_version
    assert_equal "2025-04-01", signature.document_version
    assert_predicate signature, :approved?
    assert_equal "envelope_lhecmvlheriakemt", signature.legacy_envelope_id
    assert_equal @user.reportable_nda_signature, signature
  end

  test "records the certificate it trusted so a compromise can be traced" do
    signature = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "ada@example.com")).nda_signature

    assert_equal LegacyNda::CertificateAllowlist.spki_sha256(LegacyPdfFactory.certificate),
      signature.legacy_signing_certificate_fingerprint
  end

  test "keeps both timestamps in the audit record whichever one was stored" do
    signature = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "ada@example.com")).nda_signature

    assert_equal signature.signed_at.iso8601, signature.legacy_verification["cms_signing_time"]
    assert signature.legacy_verification["certificate_page_signed_at"].present?
  end

  test "challenges a document signed from a different address" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "personal@example.com"))

    assert_predicate import, :challenge_pending?
    assert_nil import.nda_signature
    assert_nil @user.reload.reportable_nda_signature
    assert_equal [ "personal@example.com" ], sent_mail_for(:import_challenge).map { _1[:to] }
  end

  test "the challenge code never reaches the database in the clear" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "personal@example.com"))
    code = sent_mail_for(:import_challenge).first[:data_variables]["challenge_code"]

    assert code.present?
    assert_not_includes import.challenge_digest, code
    assert_equal 64, import.challenge_digest.length
  end

  test "a correct code settles the claim" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "personal@example.com"))
    code = sent_mail_for(:import_challenge).first[:data_variables]["challenge_code"]

    assert LegacyNda::EmailChallenge.verify(import, code)
    LegacyNda::Claim.settle!(import)

    assert_predicate import.reload, :approved?
    assert_equal "personal@example.com", import.nda_signature.legacy_signer_email
  end

  test "a wrong code does not settle the claim" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "personal@example.com"))

    assert_not LegacyNda::EmailChallenge.verify(import, "000000")
    assert_predicate import.reload, :challenge_pending?
    assert_nil import.nda_signature
  end

  test "an expired code does not settle the claim" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "personal@example.com"))
    code = sent_mail_for(:import_challenge).first[:data_variables]["challenge_code"]
    import.update!(challenge_expires_at: 1.second.ago)

    assert_not LegacyNda::EmailChallenge.verify(import, code)
  end

  test "codes run out after a handful of guesses" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "personal@example.com"))
    code = sent_mail_for(:import_challenge).first[:data_variables]["challenge_code"]
    LegacyNdaImport::MAX_CHALLENGE_ATTEMPTS.times { LegacyNda::EmailChallenge.verify(import, "000000") }

    assert_not LegacyNda::EmailChallenge.verify(import, code)
  end

  test "a code cannot be used twice" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "personal@example.com"))
    code = sent_mail_for(:import_challenge).first[:data_variables]["challenge_code"]

    assert LegacyNda::EmailChallenge.verify(import, code)
    assert_not LegacyNda::EmailChallenge.verify(import, code)
  end

  test "rejects a second claim on an envelope somebody already holds" do
    verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "ada@example.com"))

    users(:two).update!(email: "ada@example.com")
    second = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "ada@example.com"), user: users(:two))

    assert_predicate second, :rejected?
    assert_includes second.reasons, "already_claimed"
    assert_nil second.nda_signature
  end

  test "a revoked import frees its envelope for the rightful owner" do
    first = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "ada@example.com"))
    first.nda_signature.update!(verification_state: "rejected", legacy_envelope_id: nil, legacy_document_sha256: nil)

    users(:two).update!(email: "ada@example.com")
    second = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "ada@example.com"), user: users(:two))

    assert_predicate second, :approved?
  end

  test "rejects a document that fails verification and keeps no signature" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(
      recipient_email: "ada@example.com", key: LegacyPdfFactory.rogue_key,
      certificate: LegacyPdfFactory.rogue_certificate
    ))

    assert_predicate import, :rejected?
    assert_includes import.reasons, "untrusted_certificate"
    assert_nil import.nda_signature
    assert_empty NdaSignature.legacy
  end

  test "never settles a document with no address to bind it to" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(certificate_page: false))

    assert_predicate import, :needs_review?
    assert_empty sent_mail_for(:import_challenge), "there is no address on the document to challenge"
    assert_predicate import.nda_signature, :needs_review?
    assert_nil @user.reload.reportable_nda_signature
  end

  test "an import awaiting review is not reported as signed" do
    import = verify_import(LegacyPdfFactory.legacy_document_pdf(recipient_email: "ada@example.com", body_date: "2020-01-01"))

    assert_predicate import, :needs_review?
    assert_predicate import.nda_signature, :needs_review?
    assert_nil @user.reload.reportable_nda_signature
  end
end
