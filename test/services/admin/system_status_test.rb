require "test_helper"
require_relative "../../support/airtable_stub"

class Admin::SystemStatusTest < ActiveSupport::TestCase
  include AirtableStub

  test "reports configured Airtable without a live check" do
    with_airtable do
      status = Admin::SystemStatus.call.find { _1.name == "Airtable" }

      assert_equal :ok, status.state
      assert_equal "Configured", status.detail
    end
  end

  test "can run a live Airtable connection check" do
    with_airtable do
      status = Admin::SystemStatus.call(check_airtable: true).find { _1.name == "Airtable" }

      assert_equal :ok, status.state
      assert_equal "Live connection passed", status.detail
    end
  end
end
