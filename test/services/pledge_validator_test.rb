require "test_helper"

class PledgeValidatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @user.assign_attributes(
      legal_first_name: "Ada",
      legal_last_name: "Lovelace",
      birthdate: Date.new(2000, 1, 1),
      city: "London",
      region: "England",
      country: "United Kingdom"
    )
    @video = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/pledge.webm"),
      "video/webm"
    )
  end

  test "accepts a transcript containing the pledge" do
    transcript = PledgeScript.for(@user)
    with_transcript(transcript) do
      result = PledgeValidator.verify!(@video, user: @user)
      assert_equal transcript, result.transcript
      assert_operator result.score, :>=, 0.65
    end
  end

  test "requires the volunteer relationship acknowledgement" do
    transcript = PledgeScript.for(@user).sub(PledgeScript::BODY.second, "")

    with_transcript(transcript) do
      assert_raises(PledgeValidator::Rejected) do
        PledgeValidator.verify!(@video, user: @user)
      end
    end
  end

  test "rejects a transcript missing the pledge" do
    with_transcript("Hello, this is a video.") do
      assert_raises(PledgeValidator::Rejected) do
        PledgeValidator.verify!(@video, user: @user)
      end
    end
  end

  test "reports when no spoken audio was detected" do
    with_transcript("") do
      error = assert_raises(PledgeValidator::Rejected) do
        PledgeValidator.verify!(@video, user: @user)
      end
      assert_match "couldn't detect any spoken audio", error.message
    end
  end

  private

  def with_transcript(transcript)
    singleton = XaiTranscription.singleton_class
    original = singleton.instance_method(:call)
    singleton.define_method(:call) { |_video| transcript }
    yield
  ensure
    singleton.define_method(:call, original)
  end
end
