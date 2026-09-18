class Admin::DashboardController < ApplicationController
  before_action :require_admin

  def index
    @metrics = metrics
    @systems = Admin::SystemStatus.call(check_airtable: params[:check_airtable] == "1")
    @failed_airtable_jobs = failed_airtable_executions.count
    @users = dashboard_users
    @recent_actions = AdminAction.includes(:admin_user, :target_user).order(created_at: :desc).limit(20)
  end

  def retry_failed_airtable_jobs
    failures = failed_airtable_executions.includes(:job).to_a
    SolidQueue::FailedExecution.retry_all(failures.map(&:job)) if failures.any?
    redirect_to admin_root_path, notice: "Requeued #{failures.size} failed Airtable sync job#{'s' unless failures.one?}."
  end

  private

  def failed_airtable_executions
    SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { class_name: "SyncSignatureToAirtableJob" })
  end

  def metrics
    current = NdaSignature.where(document_version: NdaDocument::VERSION)
    approved = NdaSignature.approved
    {
      members: User.count,
      current: current.approved.count,
      current_pending: current.where.not(verification_state: "approved").count,
      legacy: approved.legacy.count,
      review: NdaSignature.legacy.needs_review.count,
      unsynced: approved.where(airtable_synced_at: nil).count
    }
  end

  def dashboard_users
    users = User.includes(:nda_signatures).order(updated_at: :desc)
    if params[:query].present?
      escaped = ActiveRecord::Base.sanitize_sql_like(params[:query].strip)
      users = users.where(
        "slack_id ILIKE :query OR email ILIKE :query OR first_name ILIKE :query OR last_name ILIKE :query",
        query: "%#{escaped}%"
      )
    end
    users.limit(100)
  end
end
