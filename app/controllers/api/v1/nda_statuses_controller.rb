class Api::V1::NdaStatusesController < ApplicationController
  def show
    id = params[:slack_id].to_s
    return render_email_status(id) if id.include?("@")

    slack_id = id.upcase
    unless slack_id.match?(User::SLACK_ID_FORMAT)
      return render json: { error: "invalid_slack_id" }, status: :bad_request
    end

    signature = User.find_by(slack_id: slack_id)&.reportable_nda_signature
    expires_in 30.seconds, public: true
    render json: status_payload(signature).merge(slack_id: slack_id)
  end

  private

  def render_email_status(address)
    response.headers["Cache-Control"] = "no-store"
    email = address.strip.downcase
    unless email.length <= 254 && email.match?(URI::MailTo::EMAIL_REGEXP)
      return render json: { error: "invalid_email" }, status: :bad_request
    end

    signature = User.where(email: email).or(User.where(verified_email: email))
      .filter_map(&:reportable_nda_signature).min_by { |s| [ s.native? ? 0 : 1, s.signed_at, s.id ] }
    render json: status_payload(signature)
  end

  def status_payload(signature)
    {
      status: signature ? "signed" : "not_signed",
      nda_version: signature&.document_version || NdaDocument::VERSION,
      signed_at: signature&.signed_at&.iso8601,
      signature_type: signature&.signature_type
    }.compact
  end
end
