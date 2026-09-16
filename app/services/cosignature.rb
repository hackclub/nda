class Cosignature
  KEY_SALT = "nda cosignature token".freeze
  TTL = 14.days
  RESEND_INTERVAL = 2.minutes

  class AlreadySigned < StandardError; end

  class << self
    def invite!(signature)
      raise AlreadySigned if signature.cosigned?

      token = SecureRandom.urlsafe_base64(32)
      signature.update!(
        cosigner_token_digest: digest(token),
        cosigner_token_expires_at: TTL.from_now,
        cosigner_invited_at: Time.current
      )
      deliver_invitation(signature, token)
      signature
    end

    def resendable?(signature)
      signature.cosignature_pending? &&
        (signature.cosigner_invited_at.nil? || signature.cosigner_invited_at < RESEND_INTERVAL.ago)
    end

    def find(token)
      return nil if token.blank?

      signature = NdaSignature.awaiting_cosigner.find_by(cosigner_token_digest: digest(token))
      signature if signature&.cosigner_token_expires_at&.future?
    end

    def countersign!(signature, name:, ip: nil, user_agent: nil)
      raise AlreadySigned if signature.cosigned?

      signature.update!(
        verification_state: "approved",
        cosigner_signed_name: name.to_s.squish,
        cosigner_signed_at: Time.current,
        cosigner_ip_address: ip,
        cosigner_user_agent: user_agent,
        cosigner_token_digest: nil,
        cosigner_token_expires_at: nil
      )

      SignatureCompletedJob.perform_later(signature.id)
      signature
    end

    def digest(token) = OpenSSL::HMAC.hexdigest("SHA256", key, token.to_s)

    private

    def deliver_invitation(signature, token)
      SendEmailJob.deliver_later(
        :cosign_request,
        to: signature.cosigner_email,
        data: {
          cosigner_name: signature.cosigner_name,
          signer_fullName: signature.user.legal_name,
          cosign_url: AppHost.url_for("/cosign/#{token}"),
          cosign_expiresOn: TTL.from_now.to_date.to_fs(:long)
        }
      )
    end

    def key = Rails.application.key_generator.generate_key(KEY_SALT, 32)
  end
end
