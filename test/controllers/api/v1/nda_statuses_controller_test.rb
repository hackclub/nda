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
end
