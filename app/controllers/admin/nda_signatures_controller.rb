class Admin::NdaSignaturesController < ApplicationController
  before_action :require_admin
  before_action :set_signature

  def update
    return redirect_to admin_root_path, alert: "Only legacy signatures can be force approved." unless @signature.legacy?
    return redirect_to admin_root_path, alert: "This signature is already approved." if @signature.approved?
    return redirect_to admin_root_path, alert: "A revoked signature cannot be force approved." if @signature.rejected?
    return redirect_to admin_root_path, alert: "A reason is required." if reason.blank?

    @signature.transaction do
      @signature.update!(verification_state: "approved", reviewed_by: current_user,
        reviewed_at: Time.current, review_note: reason)
      @signature.legacy_nda_import&.update!(state: "approved")
      audit!("force_approve")
    end
    SyncSignatureToAirtableJob.perform_later(@signature.id) if AirtableClient.configured?
    redirect_to admin_root_path, notice: "Approved #{@signature.user.slack_id}'s legacy NDA."
  end

  def destroy
    return redirect_to admin_root_path, alert: "A reason is required." if reason.blank?

    slack_id = @signature.user.slack_id
    @signature.transaction do
      audit!("destroy_signature", details: snapshot)
      @signature.legacy_nda_import&.destroy!
      @signature.destroy!
    end
    redirect_to admin_root_path, notice: "Destroyed #{slack_id}'s NDA record."
  end

  def sync
    return redirect_to admin_root_path, alert: "Only approved signatures can be synced." unless @signature.approved?
    return redirect_to admin_root_path, alert: "Airtable is not configured." unless AirtableClient.configured?

    SyncSignatureToAirtableJob.perform_later(@signature.id)
    audit!("sync_airtable")
    redirect_to admin_root_path, notice: "Queued Airtable sync for #{@signature.user.slack_id}."
  end

  private

  def set_signature
    @signature = NdaSignature.includes(:user, :legacy_nda_import).find(params[:id])
  end

  def reason = params[:reason].to_s.strip

  def audit!(action, details: {})
    AdminAction.record!(admin: current_user, target_user: @signature.user, action:, subject: @signature,
      reason:, details:)
  end

  def snapshot
    {
      "signature_type" => @signature.signature_type,
      "document_version" => @signature.document_version,
      "verification_state" => @signature.verification_state,
      "airtable_record_id" => @signature.airtable_record_id
    }.compact
  end
end
