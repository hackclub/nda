class NdaSignaturesController < ApplicationController
  before_action :require_login

  def show
    if request.xhr?
      flash.keep
      return head(:no_content)
    end

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
    signature = build_signature(video)
    signature.verification_state = "processing"
    current_user.transaction do
      current_user.save!
      signature.save!
    end
    VerifyNdaSignatureJob.perform_later(signature.id)
    redirect_to nda_signature_path,
      notice: "We got your video. You can close this page—we'll let you know when it has been processed."
  rescue ActiveRecord::RecordInvalid => error
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

  def build_signature(video)
    current_user.nda_signatures.build(
      document_version: NdaDocument::VERSION,
      document_sha256: NdaDocument.sha256,
      signed_name: params.require(:signed_name).strip,
      signed_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      cosigner_name: params[:cosigner_name],
      cosigner_email: params[:cosigner_email]
    ).tap { _1.identity_video.attach(video) }
  end

  def send_agreement
    return redirect_to nda_signature_path unless @signature&.approved?

    send_data NdaPdf.call(@signature), filename: NdaPdf.filename(@signature),
      type: "application/pdf", disposition: "attachment"
  end

  def user_params
    params.require(:user).permit(
      :legal_first_name, :legal_last_name, :email, :birthdate, :address_line_1,
      :address_line_2, :city, :region, :postal_code, :country
    )
  end
end
