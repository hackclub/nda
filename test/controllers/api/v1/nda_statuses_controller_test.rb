require "test_helper"

class Api::V1::NdaStatusesControllerTest < ActionDispatch::IntegrationTest
  test "returns not signed for an unknown Slack ID" do
    get api_v1_nda_status_url(slack_id: "U1111ABCDE")
    assert_response :success
    assert_equal "not_signed", response.parsed_body["status"]
  end

  test "rejects malformed Slack IDs" do
    get api_v1_nda_status_url(slack_id: "nope")
    assert_response :bad_request
    assert_equal "invalid_slack_id", response.parsed_body["error"]
  end

  test "returns the current signed status without private identity data" do
    signature = users(:one).nda_signatures.new(
      document_version: NdaDocument::VERSION,
      document_sha256: NdaDocument.sha256,
      signed_name: "Ada Lovelace",
      signed_at: Time.current,
      transcript: "verified"
    )
    signature.save!(validate: false)

    get api_v1_nda_status_url(slack_id: users(:one).slack_id)
    assert_response :success
    assert_equal "signed", response.parsed_body["status"]
    assert_nil response.parsed_body["email"]
    assert_nil response.parsed_body["name"]
  end

  test "reports an in-app signature as native" do
    create_signature(users(:one), signed_at: Time.current)

    get api_v1_nda_status_url(slack_id: users(:one).slack_id)

    assert_equal "signed", response.parsed_body["status"]
    assert_equal "native", response.parsed_body["signature_type"]
    assert_equal NdaDocument::VERSION, response.parsed_body["nda_version"]
  end

  test "reports an imported signature as legacy, under the legacy version" do
    signature = create_legacy_signature(users(:one), signed_at: Time.utc(2025, 12, 4, 23, 22, 32))

    get api_v1_nda_status_url(slack_id: users(:one).slack_id)

    assert_equal "signed", response.parsed_body["status"]
    assert_equal "legacy", response.parsed_body["signature_type"]
    assert_equal "2025-04-01", response.parsed_body["nda_version"]
    assert_equal signature.signed_at.iso8601, response.parsed_body["signed_at"]
  end

  test "prefers the native signature when a member holds both" do
    create_legacy_signature(users(:one), signed_at: 2.years.ago)
    native = create_signature(users(:one), signed_at: Time.current)

    get api_v1_nda_status_url(slack_id: users(:one).slack_id)

    assert_equal "native", response.parsed_body["signature_type"]
    assert_equal native.signed_at.iso8601, response.parsed_body["signed_at"]
  end

  test "an import awaiting review is not signed yet" do
    create_legacy_signature(users(:one), verification_state: "needs_review")

    get api_v1_nda_status_url(slack_id: users(:one).slack_id)

    assert_equal "not_signed", response.parsed_body["status"]
    assert_nil response.parsed_body["signature_type"]
    assert_nil response.parsed_body["signed_at"]
  end

  test "a revoked import is not signed" do
    create_legacy_signature(users(:one), verification_state: "rejected")

    get api_v1_nda_status_url(slack_id: users(:one).slack_id)

    assert_equal "not_signed", response.parsed_body["status"]
  end

  test "an unsigned response still carries the current version and nothing else" do
    get api_v1_nda_status_url(slack_id: "U1111ABCDE")

    assert_equal %w[nda_version slack_id status], response.parsed_body.keys.sort
    assert_equal NdaDocument::VERSION, response.parsed_body["nda_version"]
  end

  test "never exposes anything about the person behind an import" do
    create_legacy_signature(users(:one), legacy_signer_email: "personal@example.com",
      legacy_signer_name: "Ada Lovelace", legacy_envelope_id: "envelope_secret")

    get api_v1_nda_status_url(slack_id: users(:one).slack_id)

    assert_equal %w[nda_version signature_type signed_at slack_id status], response.parsed_body.keys.sort
    %w[personal@example.com Ada Lovelace envelope_secret needs_review].each do |leak|
      assert_not_includes response.body, leak
    end
  end
end
