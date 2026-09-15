require "test_helper"

class NotifyNdaSignedJobTest < ActiveJob::TestCase
  test "sends the completion message to the signer's Slack ID" do
    signature = create_signature(users(:one), signed_at: Time.current)
    call = nil
    singleton = SlackClient.singleton_class
    original = singleton.instance_method(:post_message)
    singleton.define_method(:post_message) { |**arguments| call = arguments }

    NotifyNdaSignedJob.perform_now(signature.id)

    assert_equal users(:one).slack_id, call[:channel]
    assert_equal NotifyNdaSignedJob::MESSAGE, call[:text]
    assert_includes call[:text], "https://nda.hackclub.com/nda_signature"
  ensure
    singleton&.define_method(:post_message, original) if original
  end
end
