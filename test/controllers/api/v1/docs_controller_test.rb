require "test_helper"

class Api::V1::DocsControllerTest < ActionDispatch::IntegrationTest
  test "documents the NDA status endpoint" do
    get api_v1_docs_url

    assert_response :success
    assert_select "title", text: "Hack Club NDA API Docs"
    assert_select "code", text: "/api/v1/nda_status/:slack_id"
    assert_select "a[href='#{openapi_path}']", text: "OpenAPI 3.1 specification"
    assert_includes response.body, NdaDocument::VERSION
    assert_not_includes response.body, "?email="
    assert_includes response.body, "/api/v1/nda_status/orpheus%40example.com"
  end

  test "publishes an OpenAPI document" do
    get openapi_url

    assert_response :success
    assert_equal "application/json", response.media_type

    document = response.parsed_body
    assert_equal "3.1.0", document["openapi"]
    assert_equal [ "/api/v1/nda_status/{slack_id}" ], document["paths"].keys
    operation = document.dig("paths", "/api/v1/nda_status/{slack_id}", "get")
    assert_equal "getNdaStatus", operation["operationId"]
    assert_equal "path", operation["parameters"].first["in"]
    assert_equal true, operation["parameters"].first["required"]
    assert_equal %w[nda_version signature_type signed_at status],
      document.dig("components", "schemas", "NdaStatusByEmail", "properties").keys.sort
    assert_equal "email", operation.dig("parameters", 0, "schema", "oneOf", 1, "format")
    assert_equal [
      { "$ref" => "#/components/schemas/NdaStatus" },
      { "$ref" => "#/components/schemas/NdaStatusByEmail" }
    ], operation.dig("responses", "200", "content", "application/json", "schema", "oneOf")
    assert_equal %w[200 400 429], operation["responses"].keys
    assert_equal [], operation["security"]
    assert_equal %w[nda_version signature_type signed_at slack_id status],
      document.dig("components", "schemas", "NdaStatus", "properties").keys.sort
    assert_equal %w[legacy native],
      document.dig("components", "schemas", "NdaStatus", "properties", "signature_type", "enum").sort
  end
end
