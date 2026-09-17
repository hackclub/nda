class Admin::UsersController < ApplicationController
  before_action :require_admin

  def reset_nda
    user = User.includes(:nda_signatures).find(params[:id])
    signature = user.signature_for_current_version
    return redirect_to admin_root_path, alert: "That member does not have a current NDA to reset." unless signature

    reason = params[:reason].to_s.strip
    return redirect_to admin_root_path, alert: "A reason is required." if reason.blank?

    signature.transaction do
      AdminAction.record!(admin: current_user, target_user: user, action: "reset_nda", subject: signature,
        reason:, details: { "document_version" => signature.document_version })
      signature.destroy!
    end
    redirect_to admin_root_path, notice: "Reset #{user.slack_id}'s current NDA. They can sign again."
  end
end
