require "test_helper"
require_relative "../support/legacy_pdf_factory"

class XaiDocumentReviewTest < ActiveSupport::TestCase
  def with_env(**values)
    original = {}
    original = values.keys.to_h { |key| [ key.to_s, ENV[key.to_s] ] }
    values.each { |key, value| ENV[key.to_s] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "is off unless it is switched on and a key is present" do
    assert_not XaiDocumentReview.enabled?

    with_env(LEGACY_AI_REVIEW: "1") { assert_not XaiDocumentReview.enabled? }
    with_env(XAI_API_KEY: "xai-test") { assert_not XaiDocumentReview.enabled? }
    with_env(LEGACY_AI_REVIEW: "1", XAI_API_KEY: "xai-test") { assert XaiDocumentReview.enabled? }
  end

  test "a concerning verdict is one that doubts the document" do
    clean = XaiDocumentReview::Result.new(is_nda: true, looks_altered: false, concerns: [], confidence: 0.9)
    not_nda = XaiDocumentReview::Result.new(is_nda: false, looks_altered: false, concerns: [ "other doc" ], confidence: 0.8)
    altered = XaiDocumentReview::Result.new(is_nda: true, looks_altered: true, concerns: [ "spliced" ], confidence: 0.6)

    assert_not clean.concerning?
    assert not_nda.concerning?
    assert altered.concerning?
  end
end

class LegacyNdaAiReviewTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  setup do
    LegacyNda::CertificateAllowlist.default = LegacyPdfFactory.allowlist
    @user = User.new(legal_first_name: "Ada", legal_last_name: "Lovelace")
    @pdf = LegacyPdfFactory.legacy_document_pdf
  end

  teardown { LegacyNda::CertificateAllowlist.reset! }

  def verify = LegacyNda::Verifier.call(@pdf, user: @user)

  test "is not consulted at all when it is switched off" do
    called = false
    with_review(-> { called = true }) { verify }

    assert_not called
    assert_nil verify.fields[:ai_review]
  end

  test "sends a clean document through unchanged" do
    result = with_review(clean_result, enabled: true) { verify }

    assert_predicate result, :approved?
    assert_equal true, result.fields[:ai_review][:is_nda]
  end

  test "sends a document it doubts to review without rejecting it" do
    result = with_review(concerned_result, enabled: true) { verify }

    assert_predicate result, :needs_review?
    assert_includes result.reasons, :ai_review_concern
    assert_not result.rejected?, "the model must never be the sole basis for a rejection"
    assert_equal [ "numbering is inconsistent" ], result.fields[:ai_review][:concerns]
  end

  test "cannot approve a document the deterministic checks rejected" do
    @pdf = LegacyPdfFactory.legacy_document_pdf(body: "some other agreement " * 50)
    result = with_review(clean_result, enabled: true) { verify }

    assert_predicate result, :rejected?
    assert_equal [ :content_mismatch ], result.reasons
  end

  test "an unavailable model does not block an import" do
    result = with_review(->(_text) { raise XaiDocumentReview::Error, "timeout" }, enabled: true) do
      silence_stream($stderr) { verify }
    end

    assert_predicate result, :approved?
    assert_nil result.fields[:ai_review]
  end

  test "only redacted text is ever sent" do
    seen = nil
    @pdf = LegacyPdfFactory.legacy_document_pdf(recipient_name: "Ada Lovelace", recipient_email: "ada@example.com")
    with_review(->(text) { seen = text; clean_value }, enabled: true) { verify }

    assert seen.present?
    assert_not_includes seen, "ada@example.com"
    assert_not_includes seen, "Ada Lovelace"
    assert_includes seen, "Confidential Information"
  end

  private

  def clean_value = XaiDocumentReview::Result.new(is_nda: true, looks_altered: false, concerns: [], confidence: 0.95)
  def clean_result = ->(_text) { clean_value }

  def concerned_result
    ->(_text) do
      XaiDocumentReview::Result.new(
        is_nda: true, looks_altered: true, concerns: [ "numbering is inconsistent" ], confidence: 0.4
      )
    end
  end

  def with_review(handler, enabled: false)
    singleton = nil
    original_call = nil
    original_enabled = nil

    singleton = XaiDocumentReview.singleton_class
    original_call = singleton.instance_method(:call)
    original_enabled = singleton.instance_method(:enabled?)
    singleton.define_method(:call) { |text| handler.arity.zero? ? handler.call : handler.call(text) }
    singleton.define_method(:enabled?) { enabled }
    yield
  ensure
    if singleton && original_call && original_enabled
      singleton.define_method(:call, original_call)
      singleton.define_method(:enabled?, original_enabled)
    end
  end
end
