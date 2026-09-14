class PledgeValidator
  Result = Data.define(:transcript, :score)
  TOKEN_OVERLAP = 0.65
  CONCEPT_OVERLAP = 0.5
  STOP_WORDS = %w[a an and i is it my of or the this to with].freeze
  REQUIRED_CONCEPTS = [
    %w[private data confidential information elevated access],
    %w[great power great responsibility uphold responsibility],
    %w[private information private responsibly privileged access permissions model member hack club]
  ].freeze

  class Error < StandardError; end
  class Rejected < Error; end

  def self.verify!(video, user:)
    validate_upload!(video)
    transcript = XaiTranscription.call(video)
    actual = tokens(transcript)
    raise Rejected, "We couldn't detect any spoken audio. Check your microphone and upload a new video." if actual.empty?

    expected = tokens(PledgeScript.for(user))
    score = (expected & actual).length.fdiv(expected.length)
    concepts_present = REQUIRED_CONCEPTS.all? do |concept|
      words = tokens(concept.join(" "))
      (words & actual).length.fdiv(words.length) >= CONCEPT_OVERLAP
    end

    unless score >= TOKEN_OVERLAP && concepts_present
      raise Rejected, "The pledge could not be verified (#{(score * 100).round}% matched). Please record it again and read every bullet clearly."
    end

    Result.new(transcript:, score:)
  rescue XaiTranscription::Error => error
    raise Error, error.message
  end

  def self.validate_upload!(video)
    unless video.respond_to?(:content_type) && video.content_type.in?(NdaSignature::VIDEO_TYPES)
      raise Rejected, "Please upload an MP4 or WebM video."
    end
    raise Rejected, "The video must be 25 MB or smaller." if video.size > NdaSignature::MAX_VIDEO_BYTES
  end

  def self.tokens(text)
    text.to_s.downcase.scan(/[a-z0-9]+/).to_set - STOP_WORDS
  end
  private_class_method :validate_upload!, :tokens
end
