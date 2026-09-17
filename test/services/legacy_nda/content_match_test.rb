require "test_helper"

class LegacyNda::ContentMatchTest < ActiveSupport::TestCase
  test "matches the canonical agreement" do
    result = LegacyNda::ContentMatch.call(NdaDocument::TEXT)

    assert result.match?
    assert_operator result.containment, :>=, LegacyNda::ContentMatch::MATCH_CONTAINMENT
    assert_equal LegacyNda::ContentMatch::HEADINGS.size, result.headings_found
    assert_empty result.headings_missing
    assert_equal 1.0, result.heading_ratio
  end

  test "matches the previous agreement after a new revision becomes current" do
    result = LegacyNda::ContentMatch.call(NdaDocument::LEGACY_TEXT)

    assert result.match?
    assert_equal 1.0, result.containment
  end

  test "matches a genuine agreement carrying extra material" do
    result = LegacyNda::ContentMatch.call(NdaDocument::TEXT + (" appendix schedule exhibit annex " * 2000))

    assert result.match?, "containment must not punish a document for being long"
    assert_operator result.containment, :>=, LegacyNda::ContentMatch::MATCH_CONTAINMENT
    assert result.jaccard < result.containment
  end

  test "rejects a different document" do
    result = LegacyNda::ContentMatch.call("This vendor services agreement is between Hack Club and the supplier. " * 60)

    assert result.mismatch?
    assert_equal 0, result.headings_found
  end

  test "rejects a truncated agreement" do
    assert LegacyNda::ContentMatch.call(NdaDocument::TEXT[0, NdaDocument::TEXT.length / 2]).mismatch?
  end

  test "rejects empty input" do
    assert LegacyNda::ContentMatch.call("").mismatch?
    assert LegacyNda::ContentMatch.call(nil).mismatch?
  end

  test "sends a document missing a clause heading to review rather than deciding" do
    result = LegacyNda::ContentMatch.call(NdaDocument::TEXT.sub("18. Counterparts", ""))

    assert_equal :uncertain, result.verdict
    assert_equal [ "18. Counterparts" ], result.headings_missing
  end

  test "redacts the recipient block before scoring, so names never affect the verdict" do
    with_recipient = NdaDocument::TEXT.sub(
      "This Mutual Non-Disclosure Agreement",
      "Recipient information (“Recipient”)\nFull name: Ada Lovelace\nEmail: ada@example.com\n" \
      "This Mutual Non-Disclosure Agreement"
    )

    assert_equal LegacyNda::ContentMatch.call(NdaDocument::TEXT).jaccard,
      LegacyNda::ContentMatch.call(with_recipient).jaccard
  end
end
