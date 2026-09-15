require "test_helper"

class NotifyNdaFailedJobTest < ActiveJob::TestCase
  test "sends a generic retry message to the user's Slack ID" do
    call = nil
    singleton = SlackClient.singleton_class
    original = singleton.instance_method(:post_message)
    singleton.define_method(:post_message) { |**arguments| call = arguments }

    NotifyNdaFailedJob.perform_now(users(:one).id)

    assert_equal users(:one).slack_id, call[:channel]
    assert_equal NotifyNdaFailedJob::MESSAGE, call[:text]
    assert_includes call[:text], "https://nda.hackclub.com/nda_signature"
    refute_includes call[:text], "No speech detected"
  ensure
    singleton&.define_method(:post_message, original) if original
  end
end
