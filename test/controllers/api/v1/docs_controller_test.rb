require "test_helper"

class Api::V1::DocsControllerTest < ActionDispatch::IntegrationTest
  test "documents the NDA status endpoint" do
    get api_v1_docs_url

    assert_response :success
    assert_select "title", "API Documentation · Hack Club NDA"
    assert_select "code", text: "/api/v1/nda_status/:slack_id"
    assert_select "a[href='#{openapi_path}']", text: "OpenAPI 3.1 specification"
    assert_includes response.body, NdaDocument::VERSION
  end

  test "publishes an OpenAPI document" do
    get openapi_url

    assert_response :success
    assert_equal "application/json", response.media_type

    document = response.parsed_body
    assert_equal "3.1.0", document["openapi"]
    operation = document.dig("paths", "/api/v1/nda_status/{slack_id}", "get")
    assert_equal "getNdaStatus", operation["operationId"]
    assert_equal %w[200 400], operation["responses"].keys
    assert_equal [], operation["security"]
    assert_equal %w[nda_version signed_at slack_id status],
      document.dig("components", "schemas", "NdaStatus", "properties").keys.sort
  end
end
