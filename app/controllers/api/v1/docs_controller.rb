class Api::V1::DocsController < ApplicationController
  def index
  end

  def openapi
    s = {
      type: "object",
      additionalProperties: false,
      required: %w[status nda_version],
      properties: {
        status: { type: "string", enum: %w[signed not_signed] },
        nda_version: { type: "string", description: "The NDA version checked." },
        signed_at: {
          type: "string", format: "date-time",
          description: "Present only when status is signed."
        },
        signature_type: {
          type: "string", enum: %w[native legacy],
          description: "How the agreement was signed. Present only when status is signed. native: completed via the new signing flow. legacy: a completed & cryptographically valid PDF imported from the previous system. Both are legally binding agreements, but it is recommended that users complete the new signing flow. If you check NDAs for a user that has signed via the legacy system, you may want to prompt them to sign again via the new flow, but do not block them from using your service if they have a valid legacy signature."
        }
      }
    }
    expires_in 1.hour, public: true
    render json: {
      openapi: "3.1.0",
      info: {
        title: "Hack Club NDA Status API",
        version: "v1",
        description: "Public API for checking whether a Hack Club member has signed the current NDA."
      },
      servers: [ { url: request.base_url } ],
      paths: {
        "/api/v1/nda_status/{slack_id}" => {
          get: {
            operationId: "getNdaStatus",
            summary: "Check a member's NDA status",
            description: "Accepts a Slack ID or URL-encoded email (for example orpheus%40example.com). Unknown identifiers return not_signed. Email lookup checks signing and verified account emails, ignoring case and surrounding whitespace, using recorded signatures only. Email responses omit Slack ID and are not cached.",
            security: [],
            parameters: [
              {
                name: "slack_id",
                in: "path",
                required: true,
                description: "A Slack member ID beginning with U or W, or a URL-encoded email address.",
                schema: { oneOf: [
                  { type: "string", pattern: "^[UW][A-Z0-9]{8,20}$" },
                  { type: "string", format: "email", maxLength: 254 }
                ] },
                example: "U0123ABCDEF"
              }
            ],
            responses: {
              "200" => {
                description: "The member's status for the current NDA version.",
                headers: {
                  "Cache-Control" => {
                    description: "Slack responses may be cached publicly for 30 seconds; email responses use no-store.",
                    schema: { type: "string" }
                  }
                },
                content: {
                  "application/json" => {
                    schema: { oneOf: [
                      { "$ref": "#/components/schemas/NdaStatus" },
                      { "$ref": "#/components/schemas/NdaStatusByEmail" }
                    ] },
                    examples: {
                      signed: {
                        summary: "Signed",
                        value: {
                          slack_id: "U0123ABCDEF", status: "signed",
                          nda_version: NdaDocument::VERSION, signed_at: "2025-04-02T15:04:05Z",
                          signature_type: "native"
                        }
                      },
                      imported: {
                        summary: "Signed, imported from the previous signing system",
                        value: {
                          slack_id: "U0123ABCDEF", status: "signed",
                          nda_version: NdaDocument::LEGACY_VERSION, signed_at: "2025-12-04T23:22:32Z",
                          signature_type: "legacy"
                        }
                      },
                      not_signed: {
                        summary: "Not signed or unknown",
                        value: {
                          slack_id: "U0123ABCDEF", status: "not_signed",
                          nda_version: NdaDocument::VERSION
                        }
                      }
                    }
                  }
                }
              },
              "400" => {
                description: "The Slack ID or email is malformed (invalid_slack_id or invalid_email).",
                content: {
                  "application/json" => {
                    schema: { "$ref": "#/components/schemas/Error" },
                    example: { error: "invalid_slack_id" }
                  }
                }
              },
              "429" => {
                description: "The client IP exceeded 10 requests in one second.",
                headers: {
                  "Retry-After" => {
                    description: "Seconds until the client can retry.",
                    schema: { type: "integer", minimum: 1 }
                  }
                },
                content: {
                  "text/plain" => {
                    schema: { type: "string" },
                    example: "Retry later\n"
                  }
                }
              }
            }
          }
        }
      },
      components: {
        schemas: {
          NdaStatus: s.merge(required: %w[slack_id status nda_version], properties: s[:properties].merge(
            slack_id: { type: "string", description: "The normalized uppercase Slack member ID." }
          )),
          NdaStatusByEmail: s,
          Error: {
            type: "object",
            additionalProperties: false,
            required: [ "error" ],
            properties: { error: { type: "string", enum: %w[invalid_slack_id invalid_email] } }
          }
        }
      }
    }
  end
end
