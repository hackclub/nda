require "test_helper"

class VerifyNdaSignatureJobTest < ActiveJob::TestCase
  setup do
    @user = users(:one)
    @user.update!(SIGNING_DETAILS.merge(current_nda_required_at: Time.current))
    @signature = create_signature(@user, signed_at: Time.current)
    @signature.update!(verification_state: "processing", transcript: nil, validation_score: nil)
    @validator = PledgeValidator.singleton_class
    @original_verify = @validator.instance_method(:verify!)
  end

  teardown { @validator.define_method(:verify!, @original_verify) }

  test "approves a valid saved recording and queues completion" do
    @validator.define_method(:verify!) do |video, user:|
      raise "missing saved upload" unless video.size.positive? && user

      PledgeValidator::Result.new(transcript: "I pledge.", score: 1.0)
    end

    assert_enqueued_with(job: SignatureCompletedJob, args: [ @signature.id ]) do
      VerifyNdaSignatureJob.perform_now(@signature.id)
    end

    assert_predicate @signature.reload, :approved?
    assert_equal "I pledge.", @signature.transcript
    assert_equal BigDecimal("1.0"), @signature.validation_score
    assert_nil @user.reload.current_nda_required_at
  end

  test "retains a rejected recording and its transcript for review" do
    result = PledgeValidator::Result.new(transcript: "Most of the pledge", score: 0.64)
    @validator.define_method(:verify!) do |*, **|
      raise PledgeValidator::Rejected.new("Pledge did not match.", result:)
    end

    previous_token = ENV["SLACK_BOT_TOKEN"]
    ENV["SLACK_BOT_TOKEN"] = "test-token"
    assert_enqueued_with(job: NotifyNdaFailedJob, args: [ @user.id ]) do
      VerifyNdaSignatureJob.perform_now(@signature.id)
    end

    assert_predicate @signature.reload, :rejected?
    assert_predicate @signature.identity_video, :attached?
    assert_equal "Most of the pledge", @signature.transcript
    assert_equal BigDecimal("0.64"), @signature.validation_score
  ensure
    ENV["SLACK_BOT_TOKEN"] = previous_token
  end

  test "keeps transient transcription failures queued without losing the recording" do
    @validator.define_method(:verify!) { |*, **| raise PledgeValidator::Error, "temporarily unavailable" }

    assert_enqueued_with(job: VerifyNdaSignatureJob) do
      VerifyNdaSignatureJob.perform_now(@signature.id)
    end

    assert_predicate @signature.reload, :processing?
    assert_predicate @signature.identity_video, :attached?
  end

  test "invites a minor's guardian only after the recording passes" do
    @user.update!(birthdate: Date.new(2011, 3, 4))
    @signature.update!(cosigner_name: "Byron Lovelace", cosigner_email: "parent@example.com")
    @validator.define_method(:verify!) do |*, **|
      PledgeValidator::Result.new(transcript: "I pledge.", score: 1.0)
    end

    with_stubbed_mail { VerifyNdaSignatureJob.perform_now(@signature.id) }

    assert_predicate @signature.reload, :awaiting_cosigner?
    assert_equal [ "parent@example.com" ], sent_mail_for(:cosign_request).map { _1[:to] }
    assert_nil @user.reload.reportable_nda_signature
  end
end
