require "test_helper"

class NdaDocumentTest < ActiveSupport::TestCase
  test "carries all eighteen sections in the source order" do
    assert_equal (1..18).to_a, NdaDocument::SECTIONS.map { |title, _| title.to_i }
  end

  test "cross-references point at the sections they mean" do
    assert_equal 2, NdaDocument::TEXT.scan("compliance with Section 6 below").size
    assert_includes NdaDocument::TEXT, "described in Section 4 above"
    assert_includes NdaDocument::TEXT, "violation of this Section 7"
    assert_includes NdaDocument::TEXT, "provisions of Section 6 hereof"
    assert_not_includes NdaDocument::TEXT, "Section 8 below"
    assert_not_includes NdaDocument::TEXT, "Section 8 hereof"
    assert_not_includes NdaDocument::TEXT, "Section 9 provided"
  end

  test "the hash covers the whole agreement" do
    assert_equal Digest::SHA256.hexdigest(NdaDocument::TEXT), NdaDocument.sha256
    assert_includes NdaDocument::TEXT, "15 Falls Road, Shelburne, VT 05482"
    assert_includes NdaDocument::TEXT, "(A) Reasonable Care"
    assert_includes NdaDocument::TEXT, NdaDocument::FOOTER
  end

  test "the current revision explains the signer relationship" do
    assert_equal "2026-09-17", NdaDocument::VERSION
    assert_includes NdaDocument::TEXT, "serving as a volunteer"
    assert_includes NdaDocument::TEXT, "does not create an employment or independent contractor relationship"
    assert_not_includes NdaDocument::LEGACY_TEXT, "serving as a volunteer"
    assert_includes NdaDocument::LEGACY_TEXT, NdaDocument::LEGACY_FOOTER
  end

  test "renders every section and sub-clause" do
    html = ApplicationController.render(partial: "nda_signatures/document")

    NdaDocument::SECTIONS.each { |title, _| assert_includes html, title }
    assert_equal 11, html.scan("contract-clause").size
    assert_includes html, "<h4"
  end

  test "renders the parties and the AGREED block for a signature" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.update!(cosigner_name: "Anne Byron", cosigner_email: "anne@example.com")

    html = ApplicationController.render(partial: "nda_signatures/document", locals: { signature: signature })

    assert_includes html, "AGREED"
    assert_includes html, signature.user.legal_name
    assert_includes html, "Anne Byron"
    assert_includes html, "anne@example.com"
  end

  test "the print-only certificate carries what an exported PDF needs to be checked" do
    signature = create_signature(users(:one), signed_at: Time.current)
    signature.update!(ip_address: "203.0.113.7", user_agent: "Mozilla/5.0 (probe)")

    html = ApplicationController.render(partial: "nda_signatures/document", locals: { signature: signature })

    assert_includes html, "print-certificate"
    assert_includes html, signature.user.slack_id
    assert_includes html, NdaDocument::VERSION
    assert_not_includes html, NdaDocument.sha256
    assert_not_includes html, "203.0.113.7"
    assert_not_includes html, "Mozilla/5.0 (probe)"
  end
end
