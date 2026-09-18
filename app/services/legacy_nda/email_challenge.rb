module LegacyNda
  class EmailChallenge
    KEY_SALT = "legacy nda email challenge".freeze
    RESEND_INTERVAL = 2.minutes

    class TooManyAttempts < StandardError; end

    class << self
      def issue!(import, email:)
        code = format("%06d", SecureRandom.random_number(1_000_000))
        import.update!(
          state: "challenge_pending",
          challenge_email: email,
          challenge_digest: digest(code),
          challenge_expires_at: LegacyNdaImport::CHALLENGE_TTL.from_now,
          challenge_attempts: 0
        )
        deliver(email, code)
        import
      end

      def resendable?(import)
        import.challenge_pending? && import.challenge_email.present? && import.updated_at < RESEND_INTERVAL.ago
      end

      def verify(import, code)
        return false unless import.challenge_live?

        import.increment!(:challenge_attempts)
        matched = ActiveSupport::SecurityUtils.secure_compare(import.challenge_digest, digest(code.to_s.strip))
        return false unless matched

        yield if block_given?
        import.update!(challenge_digest: nil, challenge_expires_at: nil)
        true
      end

      private

      def deliver(email, code)
        SendEmailJob.deliver_later(
          :import_challenge,
          to: email,
          data: { challenge_code: code, challenge_expiresIn: LegacyNdaImport::CHALLENGE_TTL.inspect }
        )
      end

      def digest(code)
        OpenSSL::HMAC.hexdigest("SHA256", key, code)
      end

      def key = Rails.application.key_generator.generate_key(KEY_SALT, 32)
    end
  end
end
