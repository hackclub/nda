require "test_helper"

class Admin::DashboardControllerAccessTest < ActionDispatch::IntegrationTest
  test "turns away anyone who is not signed in" do
    get admin_root_url
    assert_redirected_to root_url
  end
end

class Admin::DashboardControllerTest < ActionController::TestCase
  tests Admin::DashboardController

  setup do
    @admin = users(:two)
    @admin.update!(admin: true)
    @previous_admins = ENV["ADMIN_SLACK_IDS"]
    ENV["ADMIN_SLACK_IDS"] = @admin.slack_id
    session[:user_id] = @admin.id
  end

  teardown { @previous_admins.nil? ? ENV.delete("ADMIN_SLACK_IDS") : ENV["ADMIN_SLACK_IDS"] = @previous_admins }

  test "turns away a signed in non-admin" do
    session[:user_id] = users(:one).id
    get :index
    assert_redirected_to root_path
  end

  test "shows coverage systems and members" do
    create_signature(users(:one), signed_at: Time.current)

    get :index

    assert_response :success
    assert_select "h1", "NDA control room"
    assert_select ".metric-grid"
    assert_select ".system-card", 4
    assert_select ".admin-table tbody tr", 2
    assert_select "a.admin-link", "Admin"
  end

  test "filters members without treating search metacharacters as wildcards" do
    get :index, params: { query: users(:one).slack_id }
    assert_select ".admin-table tbody tr", 1

    get :index, params: { query: "%" }
    assert_select ".empty-cell", 1
  end

  test "offers to move a legacy member to the current NDA" do
    create_legacy_signature(users(:one))

    get :index, params: { query: users(:one).slack_id }

    assert_select "form[action=?]", require_current_nda_admin_user_path(users(:one)) do
      assert_select "input[type=submit][value='Move to current NDA']"
      assert_select "input[name=reason][required]"
    end
  end

  test "retries only failed Airtable sync jobs" do
    active_job = SyncSignatureToAirtableJob.new(123)
    job = SolidQueue::Job.create!(
      queue_name: "default", class_name: active_job.class.name, arguments: active_job.serialize,
      active_job_id: active_job.job_id, scheduled_at: Time.current
    )
    failure = SolidQueue::FailedExecution.create!(
      job: job, error: { exception_class: "AirtableClient::Error", message: "failed", backtrace: [] }
    )

    post :retry_failed_airtable_jobs

    assert_redirected_to admin_root_path
    assert_not failure.class.exists?(failure.id)
    assert SolidQueue::ReadyExecution.exists?(job_id: job.id)
  end
end
