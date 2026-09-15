class Api::V1::DocsController < ApplicationController
  def index
  end

  def openapi
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
            description: "Returns signed status for the current NDA version. Unknown Slack IDs return not_signed.",
            security: [],
            parameters: [
              {
                name: "slack_id",
                in: "path",
                required: true,
                description: "A Slack member ID beginning with U or W.",
                schema: { type: "string", pattern: "^[UW][A-Z0-9]{8,20}$" },
                example: "U0123ABCDEF"
              }
            ],
            responses: {
              "200" => {
                description: "The member's status for the current NDA version.",
                headers: {
                  "Cache-Control" => {
                    description: "Responses may be cached publicly for 30 seconds.",
                    schema: { type: "string" }
                  }
                },
                content: {
                  "application/json" => {
                    schema: { "$ref": "#/components/schemas/NdaStatus" },
                    examples: {
                      signed: {
                        summary: "Signed",
                        value: {
                          slack_id: "U0123ABCDEF", status: "signed",
                          nda_version: NdaDocument::VERSION, signed_at: "2025-04-02T15:04:05Z"
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
                description: "The Slack ID is malformed.",
                content: {
                  "application/json" => {
                    schema: { "$ref": "#/components/schemas/Error" },
                    example: { error: "invalid_slack_id" }
                  }
                }
              }
            }
          }
        }
      },
      components: {
        schemas: {
          NdaStatus: {
            type: "object",
            additionalProperties: false,
            required: %w[slack_id status nda_version],
            properties: {
              slack_id: { type: "string", description: "The normalized uppercase Slack member ID." },
              status: { type: "string", enum: %w[signed not_signed] },
              nda_version: { type: "string", description: "The NDA version checked." },
              signed_at: {
                type: "string", format: "date-time",
                description: "Present only when status is signed."
              }
            }
          },
          Error: {
            type: "object",
            additionalProperties: false,
            required: [ "error" ],
            properties: { error: { type: "string", enum: [ "invalid_slack_id" ] } }
          }
        }
      }
    }
  end
end
