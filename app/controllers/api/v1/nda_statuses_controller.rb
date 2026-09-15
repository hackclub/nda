class Api::V1::NdaStatusesController < ApplicationController
  def show
    slack_id = params[:slack_id].to_s.upcase
    unless slack_id.match?(User::SLACK_ID_FORMAT)
      return render json: { error: "invalid_slack_id" }, status: :bad_request
    end

    signature = User.find_by(slack_id: slack_id)&.reportable_nda_signature
    expires_in 30.seconds, public: true
    render json: {
      slack_id: slack_id,
      status: signature ? "signed" : "not_signed",
      nda_version: signature&.document_version || NdaDocument::VERSION,
      signed_at: signature&.signed_at&.iso8601,
      signature_type: signature&.signature_type
    }.compact
  end
end
