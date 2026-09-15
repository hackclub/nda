require "test_helper"
require_relative "../../support/legacy_pdf_factory"

class LegacyNda::VerifierTest < ActiveSupport::TestCase
  setup { @user = User.new(legal_first_name: "Ada", legal_last_name: "Lovelace") }

  def verify(pdf, user: @user)
    LegacyNda::Verifier.call(pdf, user: user, allowlist: LegacyPdfFactory.allowlist)
  end

  test "approves a complete document and records what it found" do
    result = verify(LegacyPdfFactory.legacy_document_pdf)

    assert_predicate result, :approved?
    assert_empty result.reasons
    assert_equal "envelope_lhecmvlheriakemt", result.fields[:envelope_id]
    assert_equal "ada@example.com", result.fields[:signer_email]
    assert_equal "Ada Lovelace", result.fields[:signer_name]
    assert_equal 1.0, result.fields[:content_containment]
    assert_equal LegacyNda::Verifier::VERSION, result.fields[:verifier_version]
  end

  test "records the co-signer when the document has one" do
    result = verify(LegacyPdfFactory.legacy_document_pdf(cosigner_name: "Grace Hopper", cosigner_email: "g@example.com"))

    assert_predicate result, :approved?
    assert result.fields[:cosigner_present]
    assert result.fields[:cosigner_signed_at].present?
  end

  test "reports no co-signer when the block is unfilled" do
    assert_not verify(LegacyPdfFactory.legacy_document_pdf).fields[:cosigner_present]
  end

  test "keeps both timestamps so the stored one can be traced" do
    fields = verify(LegacyPdfFactory.legacy_document_pdf).fields

    assert_equal fields[:cms_signing_time], fields[:signed_at]
    assert fields[:certificate_page_signed_at].present?
    assert fields[:body_date].present?
  end

  test "sends a document whose printed name differs from the account to review" do
    result = verify(LegacyPdfFactory.legacy_document_pdf, user: User.new(legal_first_name: "Someone", legal_last_name: "Else"))

    assert_predicate result, :needs_review?
    assert_includes result.reasons, :printed_name_differs
  end

  test "cannot check a name the member has not given us" do
    assert_predicate verify(LegacyPdfFactory.legacy_document_pdf, user: User.new), :approved?
  end

  test "sends a document whose body date is far from its signing time to review" do
    result = verify(LegacyPdfFactory.legacy_document_pdf(body_date: "2020-01-01"))

    assert_predicate result, :needs_review?
    assert_includes result.reasons, :body_date_disagrees
  end

  test "tolerates a body date one day either side of the signing time" do
    assert_predicate verify(LegacyPdfFactory.legacy_document_pdf(body_date: Date.current.yesterday.to_s)), :approved?
    assert_predicate verify(LegacyPdfFactory.legacy_document_pdf(body_date: Date.current.tomorrow.to_s)), :approved?
  end

  test "sends a document with no certificate page to review rather than rejecting it" do
    result = verify(LegacyPdfFactory.legacy_document_pdf(certificate_page: false))

    assert_predicate result, :needs_review?
    assert_includes result.reasons, :no_certificate_page
    assert_includes result.reasons, :envelope_id_missing
    assert_nil result.fields[:signer_email]
  end

  test "still reads the signer and co-signer from the body when there is no certificate page" do
    fields = verify(LegacyPdfFactory.legacy_document_pdf(
      certificate_page: false, cosigner_name: "Grace Hopper", cosigner_email: "g@example.com"
    )).fields

    assert_equal "Ada Lovelace", fields[:signer_name]
    assert fields[:cosigner_present]
    assert_equal fields[:cms_signing_time], fields[:signed_at]
  end

  test "rejects a document that is not the Hack Club NDA" do
    result = verify(LegacyPdfFactory.legacy_document_pdf(body: "Some other vendor agreement " * 50))

    assert_predicate result, :rejected?
    assert_equal [ :content_mismatch ], result.reasons
  end

  test "rejects a document signed by an unpinned key" do
    result = verify(LegacyPdfFactory.legacy_document_pdf(
      key: LegacyPdfFactory.rogue_key, certificate: LegacyPdfFactory.rogue_certificate
    ))

    assert_predicate result, :rejected?
    assert_equal [ :untrusted_certificate ], result.reasons
  end

  test "rejects a document whose text was altered after signing" do
    pdf = LegacyPdfFactory.legacy_document_pdf
    altered = pdf.sub("Ada Lovelace", "Bob Lovelace")

    assert_equal pdf.bytesize, altered.bytesize
    assert_equal [ :signature_mismatch ], verify(altered).reasons
  end

  test "rejects a document with no envelope id to claim" do
    assert_equal [ :envelope_id_missing ], verify(LegacyPdfFactory.legacy_document_pdf(envelope_id: "")).reasons
  end

  test "rejects bytes that are not a PDF at all" do
    assert_equal [ :not_a_pdf ], verify("hello, not a pdf").reasons
  end

  test "carries no extracted fields on a rejection" do
    assert_empty verify("hello, not a pdf").fields
  end
end
