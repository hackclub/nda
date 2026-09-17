class NdaSignaturesController < ApplicationController
  before_action :require_login

  def show
    @signature = current_user.signature_for_current_version
    @covered_by = current_user.reportable_nda_signature if @signature.nil?
    @sign_new = params[:sign_new] == "1" || current_user.current_nda_required_at?
    respond_to do |format|
      format.html
      format.pdf { send_agreement }
    end
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
    signature = build_signature(video, result)
    signature.verification_state = "awaiting_cosigner" if signature.requires_cosignature?
    current_user.transaction do
      current_user.current_nda_required_at = nil
      current_user.save!
      signature.save!
    end
    if signature.awaiting_cosigner?
      Cosignature.invite!(signature)
      return redirect_to nda_signature_path,
        notice: "Almost there! We've emailed #{signature.cosigner_email} a link for your parent or guardian to sign."
    end

    SignatureCompletedJob.perform_later(signature.id)
    redirect_to nda_signature_path, notice: "NDA signed on #{signature.signed_at.to_date.to_fs(:long)}."
  rescue PledgeValidator::Rejected => error
    return save_rejected_attempt(video, error) if error.result

    enqueue_failure_notification
    render_video_retry(error.message)
  rescue PledgeValidator::Error => error
    Rails.logger.warn("xAI transcription failed: #{error.message}")
    enqueue_failure_notification
    render_video_retry("We couldn't validate the video right now. Please upload it again.")
  rescue ActiveRecord::RecordInvalid => error
    enqueue_failure_notification
    redirect_to nda_signature_path, alert: error.record.errors.full_messages.to_sentence
  end

  def resend_cosigner_invite
    signature = current_user.signature_for_current_version
    unless signature && Cosignature.resendable?(signature)
      return redirect_to nda_signature_path
    end

    Cosignature.invite!(signature)
    redirect_to nda_signature_path, notice: "Sent a fresh link to #{signature.cosigner_email}."
  end

  def retry
    signature = current_user.signature_for_current_version
    unless signature&.native? && signature.rejected?
      return redirect_to nda_signature_path
    end

    signature.destroy!
    redirect_to nda_signature_path, notice: "Your saved recording was removed. You can try again now."
  end

  private

  def save_rejected_attempt(video, error)
    signature = build_signature(video, error.result)
    signature.verification_state = "rejected"
    current_user.transaction do
      current_user.save!
      signature.save!
    end
    enqueue_failure_notification
    redirect_to nda_signature_path, alert: "#{error.message} Your recording was saved."
  end

  def build_signature(video, result)
    current_user.nda_signatures.build(
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
    ).tap { _1.identity_video.attach(video) }
  end

  def send_agreement
    return redirect_to nda_signature_path unless @signature&.approved?

    send_data NdaPdf.call(@signature), filename: NdaPdf.filename(@signature),
      type: "application/pdf", disposition: "attachment"
  end

  def enqueue_failure_notification
    NotifyNdaFailedJob.perform_later(current_user.id) if SlackClient.configured?
  end

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
