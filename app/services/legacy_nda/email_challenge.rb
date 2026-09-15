module LegacyNda
  class EmailChallenge
    KEY_SALT = "legacy nda email challenge".freeze

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

      def verify(import, code)
        return false unless import.challenge_live?

        import.increment!(:challenge_attempts)
        matched = ActiveSupport::SecurityUtils.secure_compare(import.challenge_digest, digest(code.to_s.strip))
        import.update!(challenge_digest: nil, challenge_expires_at: nil) if matched
        matched
      end

      private

      def deliver(email, code)
        LoopsClient.send_email(
          to: email,
          transactional_id: ENV["LOOPS_IMPORT_CHALLENGE_TRANSACTIONAL_ID"],
          data_variables: { code: code, expiresIn: LegacyNdaImport::CHALLENGE_TTL.inspect }
        )
      end

      def digest(code)
        OpenSSL::HMAC.hexdigest("SHA256", key, code)
      end

      def key = Rails.application.key_generator.generate_key(KEY_SALT, 32)
    end
  end
end
