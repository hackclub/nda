require "test_helper"

class AdminAccessTest < ActiveSupport::TestCase
  def with_admins(value)
    ENV["ADMIN_SLACK_IDS"] = value
    yield
  ensure
    ENV.delete("ADMIN_SLACK_IDS")
  end

  test "reads the review allowlist from the environment" do
    with_admins(" u0123abcde , U9876ZYXWV ") do
      assert_equal %w[U0123ABCDE U9876ZYXWV], User.admin_slack_ids
    end
  end

  test "grants nobody review access by default" do
    assert_empty User.admin_slack_ids
    assert_not users(:one).admin?
  end
end
