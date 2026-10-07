require "test_helper"

class Api::V1::NdaStatusesControllerTest < ActionDispatch::IntegrationTest
  test "looks up a signing email case insensitively without exposing identity" do
    signature = create_signature(users(:one), signed_at: Time.current)

    get "/api/v1/nda_status/%20ADA%40example.com%20"

    assert_response :success
    assert_equal({
      "status" => "signed", "nda_version" => NdaDocument::VERSION,
      "signed_at" => signature.signed_at.iso8601, "signature_type" => "native"
    }, response.parsed_body)
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "looks up encoded emails in the path without treating dots as a format" do
    create_signature(users(:one), signed_at: Time.current)
    users(:one).update!(email: "ada.lovelace+nda@example.com")

    get "/api/v1/nda_status/ADA.LOVELACE%2Bnda%40example.com"
    assert_response :success
    p = response.parsed_body
    assert_equal "signed", p["status"]
    assert_equal %w[nda_version signature_type signed_at status], p.keys.sort
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "malformed path emails cannot be overridden by a query email" do
    create_signature(users(:one), signed_at: Time.current)
    get "/api/v1/nda_status/bad%40", params: { email: users(:one).email }

    assert_response :bad_request
    assert_equal({ "error" => "invalid_email" }, response.parsed_body)
  end

  test "also looks up the verified account email" do
    create_signature(users(:one), signed_at: Time.current)
    users(:one).update!(email: "signing@example.com")

    get api_v1_nda_status_url(slack_id: "ada@example.com")

    assert_response :success
    assert_equal "signed", response.parsed_body["status"]
  end

  test "unknown and unsigned emails have the same response" do
    [ "orpheus%40example.com", ERB::Util.url_encode(users(:one).email) ].each do |e|
      get "/api/v1/nda_status/#{e}"

      assert_response :success
      assert_equal({ "status" => "not_signed", "nda_version" => NdaDocument::VERSION }, response.parsed_body)
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  end

  test "rejects malformed and overlong emails" do
    [ "a@", "@example.com", "a" * 243 + "@example.com" ].each do |email|
      get api_v1_nda_status_url(slack_id: email)

      assert_response :bad_request
      assert_equal({ "error" => "invalid_email" }, response.parsed_body)
    end
  end

  test "email lookup reports approved legacy signatures" do
    signature = create_legacy_signature(users(:one))

    get api_v1_nda_status_url(slack_id: users(:one).email)

    assert_response :success
    assert_equal "legacy", response.parsed_body["signature_type"]
    assert_equal signature.document_version, response.parsed_body["nda_version"]
  end

  test "email lookup excludes unapproved signatures and outdated native signatures" do
    s = create_signature(users(:one), signed_at: Time.current)
    %w[needs_review rejected processing awaiting_cosigner].each do |state|
      s.update!(verification_state: state)
      get api_v1_nda_status_url(slack_id: users(:one).email)
      assert_equal "not_signed", response.parsed_body["status"]
    end
    s.update!(document_version: "old-version", verification_state: "approved")
    get api_v1_nda_status_url(slack_id: users(:one).email)
    assert_equal "not_signed", response.parsed_body["status"]
  end

  test "email lookup does not report pending or revoked legacy imports" do
    s = create_legacy_signature(users(:one))
    %w[needs_review rejected].each do |state|
      s.update!(verification_state: state)
      get api_v1_nda_status_url(slack_id: users(:one).email)
      assert_equal({ "status" => "not_signed", "nda_version" => NdaDocument::VERSION }, response.parsed_body)
    end
  end

  test "shared emails prefer signed records and current native over legacy" do
    users(:two).update!(verified_email: users(:one).email)
    create_legacy_signature(users(:one))
    create_signature(users(:two), signed_at: Time.current)

    get api_v1_nda_status_url(slack_id: users(:one).email)

    assert_equal "native", response.parsed_body["signature_type"]
    assert_equal %w[nda_version signature_type signed_at status], response.parsed_body.keys.sort
  end

  test "email query lookup no longer has a route" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/api/v1/nda_status", method: :get)
    end
  end

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
