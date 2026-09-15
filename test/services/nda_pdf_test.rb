require "test_helper"
require "pdf-reader"

class NdaPdfTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @signature = create_signature(@user, signed_at: Time.utc(2026, 3, 4, 5, 6))
  end

  def text_of(signature) = PDF::Reader.new(StringIO.new(NdaPdf.call(signature))).pages.map(&:text).join("\n")

  test "carries the agreement as text a reader can extract" do
    result = LegacyNda::ContentMatch.call(text_of(@signature))

    assert_predicate result, :match?
    assert_equal 18, result.headings_found
    assert_empty result.headings_missing
  end

  test "records who signed and how to check it" do
    text = text_of(@signature)

    assert_includes text, "Ada Lovelace"
    assert_includes text, @user.slack_id
    assert_includes text, @signature.document_version
    assert_includes text, @signature.document_sha256
    assert_includes text, "AGREED"
  end

  test "names a co-signer only when there is one" do
    assert_not_includes text_of(@signature), "Co-signer Signature"

    @signature.update!(cosigner_name: "Grace Hopper", cosigner_email: "grace@example.com")
    text = text_of(@signature.reload)
    assert_includes text, "Co-signer Signature"
    assert_includes text, "Grace Hopper"
  end

  test "names the file the way the old system did" do
    assert_equal "Ada Lovelace - Hack Club Contributor NDA.pdf", NdaPdf.filename(@signature)
  end

  test "keeps a name with a slash or a quote out of the filename" do
    @user.update!(legal_first_name: %(A"da/..), legal_last_name: "Lovelace")

    assert_equal "Ada.. Lovelace - Hack Club Contributor NDA.pdf", NdaPdf.filename(@signature.reload)
  end

  test "renders the typographic quotes in the agreement rather than raising" do
    assert_includes NdaDocument::TEXT, "“"
    assert_includes text_of(@signature), "Confidential Information"
  end

  test "fits inside what Airtable will accept" do
    assert_operator NdaPdf.call(@signature).bytesize, :<, AirtableClient::MAX_ATTACHMENT_BYTES
  end
end
