require "tempfile"

class VerifyNdaSignatureJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound
  retry_on PledgeValidator::Error, wait: :polynomially_longer, attempts: 5 do |job, _error|
    signature = NdaSignature.find_by(id: job.arguments.first)
    next unless signature&.processing?

    signature.update!(verification_state: "rejected")
    VerifyNdaSignatureJob.notify_failure(signature)
  end

  def perform(signature_id)
    signature = NdaSignature.includes(:user).find(signature_id)
    return unless signature.processing?

    result = verify(signature)
    finish(signature, result)
  rescue PledgeValidator::Rejected => error
    reject(signature, error.result)
  end

  private

  def verify(signature)
    blob = signature.identity_video.blob
    extension = blob.filename.extension_with_delimiter
    Tempfile.create([ "nda-pledge", extension ], binmode: true) do |file|
      file.write(SseCustomerBlob.download(blob))
      file.rewind
      upload = ActionDispatch::Http::UploadedFile.new(
        tempfile: file, filename: blob.filename.to_s, type: blob.content_type
      )
      PledgeValidator.verify!(upload, user: signature.user)
    end
  rescue SseCustomerBlob::Error => error
    raise PledgeValidator::Error, error.message
  end

  def finish(signature, result)
    awaiting_cosigner = signature.requires_cosignature?
    signature.transaction do
      signature.lock!
      return unless signature.processing?

      signature.update!(
        transcript: result.transcript,
        validation_score: result.score,
        verification_state: awaiting_cosigner ? "awaiting_cosigner" : "approved"
      )
      signature.user.update!(current_nda_required_at: nil)
    end

    if awaiting_cosigner
      Cosignature.invite!(signature)
    else
      SignatureCompletedJob.perform_later(signature.id)
    end
  end

  def reject(signature, result)
    signature.with_lock do
      return unless signature.processing?

      signature.update!(
        verification_state: "rejected",
        transcript: result&.transcript,
        validation_score: result&.score
      )
    end
    self.class.notify_failure(signature)
  end

  def self.notify_failure(signature)
    NotifyNdaFailedJob.perform_later(signature.user_id) if SlackClient.configured?
  end
end
