class Admin::LegacyNdaImportsController < ApplicationController
  before_action :require_admin

  def index
    @signatures = NdaSignature.legacy.needs_review.includes(:user, :legacy_nda_import).order(:created_at)
    @recent = NdaSignature.legacy.where.not(reviewed_at: nil).includes(:user, :reviewed_by)
      .order(reviewed_at: :desc).limit(20)
  end

  def update
    signature = NdaSignature.legacy.find(params[:id])
    unless params[:decision].in?(%w[approve revoke])
      return redirect_to admin_legacy_nda_imports_path, alert: "Choose approve or revoke."
    end
    if params[:note].blank?
      return redirect_to admin_legacy_nda_imports_path, alert: "A reason is required."
    end
    unless signature.needs_review?
      return redirect_to admin_legacy_nda_imports_path, alert: "That import is no longer awaiting review."
    end

    case params[:decision]
    when "approve" then approve!(signature)
    when "revoke" then revoke!(signature)
    end

    redirect_to admin_legacy_nda_imports_path, notice: "Import #{signature.id} #{params[:decision]}d."
  end

  private

  def approve!(signature)
    signature.transaction do
      signature.update!(verification_state: "approved", **review_attributes)
      signature.legacy_nda_import&.update!(state: "approved")
      AdminAction.record!(admin: current_user, target_user: signature.user, action: "force_approve",
        subject: signature, reason: params[:note])
    end
    SyncSignatureToAirtableJob.perform_later(signature.id) if AirtableClient.configured?
    LegacyNda::ImportMailer.settled(signature.legacy_nda_import) if signature.legacy_nda_import
  end

  def revoke!(signature)
    signature.transaction do
      signature.update!(
        verification_state: "rejected", legacy_envelope_id: nil, legacy_document_sha256: nil, **review_attributes
      )
      signature.legacy_nda_import&.update!(state: "rejected")
      AdminAction.record!(admin: current_user, target_user: signature.user, action: "revoke",
        subject: signature, reason: params[:note])
    end
    LegacyNda::ImportMailer.rejected(signature.legacy_nda_import) if signature.legacy_nda_import
  end

  def review_attributes
    { reviewed_by: current_user, reviewed_at: Time.current, review_note: params[:note].presence }
  end
end
