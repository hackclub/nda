require "test_helper"

class SendEmailJobTest < ActiveJob::TestCase
  test "encrypts recipient and template data in the queue" do
    with_loops_configuration do
      assert_enqueued_with(job: SendEmailJob) do
        SendEmailJob.deliver_later(:import_challenge, to: "private@example.com", data: { challenge_code: "123456" })
      end
    end

    serialized = enqueued_jobs.last.fetch(:args).to_json
    refute_includes serialized, "private@example.com"
    refute_includes serialized, "123456"
    refute_includes serialized, "import_challenge"
  end

  test "decrypts and delivers a queued message" do
    with_loops_configuration do
      with_stubbed_mail do
        SendEmailJob.deliver_later(:import_challenge, to: "private@example.com", data: { challenge_code: "123456" })
      end
    end

    mail = sent_mail_for(:import_challenge).sole
    assert_equal "private@example.com", mail[:to]
    assert_equal "123456", mail[:data_variables]["challenge_code"]
  end

  private

  def with_loops_configuration(&block)
    send(:with_loops_env, &block)
  end
end
