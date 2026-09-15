require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  setup do
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.cache.store = @original_store
  end

  test "allows ten requests per second from an IP then throttles it" do
    travel_to Time.zone.at(1_700_000_000) do
      10.times do
        get root_url
        assert_response :success
      end

      get root_url
      assert_response :too_many_requests
      assert_equal "1", response.headers["Retry-After"]

      get root_url, headers: { "REMOTE_ADDR" => "192.0.2.2" }
      assert_response :success
    end
  end
end
