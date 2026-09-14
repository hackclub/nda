class NdaSignaturesController < ApplicationController
  before_action :require_login

  def show
    @signature = current_user.signature_for_current_version
  end

  def create
    if current_user.signature_for_current_version
      return redirect_to nda_signature_path, notice: "You have already signed this version."
    end
    unless ActiveModel::Type::Boolean.new.cast(params[:accepted])
      return redirect_to nda_signature_path, alert: "You must agree to the NDA before signing."
    end

    current_user.assign_attributes(user_params)
    raise ActiveRecord::RecordInvalid, current_user unless current_user.valid?

    video = params.require(:identity_video)
    result = PledgeValidator.verify!(video, user: current_user)
    signature = current_user.nda_signatures.build(
      document_version: NdaDocument::VERSION,
      document_sha256: NdaDocument.sha256,
      signed_name: params.require(:signed_name).strip,
      signed_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      transcript: result.transcript,
      validation_score: result.score,
      cosigner_name: params[:cosigner_name],
      cosigner_email: params[:cosigner_email]
    )
    signature.identity_video.attach(video)
    current_user.transaction do
      current_user.save!
      signature.save!
    end
    redirect_to nda_signature_path, notice: "NDA signed on #{signature.signed_at.to_date.to_fs(:long)}."
  rescue PledgeValidator::Rejected => error
    render_video_retry(error.message)
  rescue PledgeValidator::Error => error
    Rails.logger.warn("xAI transcription failed: #{error.message}")
    render_video_retry("We couldn't validate the video right now. Please upload it again.")
  rescue ActiveRecord::RecordInvalid => error
    redirect_to nda_signature_path, alert: error.record.errors.full_messages.to_sentence
  end

  private

  def render_video_retry(message)
    @retry_video = true
    @signed_name = params[:signed_name]
    @cosigner_name = params[:cosigner_name]
    @cosigner_email = params[:cosigner_email]
    flash.now.alert = message
    render :show, status: :unprocessable_entity
  end

  def user_params
    params.require(:user).permit(
      :legal_first_name, :legal_last_name, :email, :birthdate, :address_line_1,
      :address_line_2, :city, :region, :postal_code, :country
    )
  end
end
