module LegacyNda
  # One person can hold two Hack Club accounts (a personal one and an HQ one), each with its own Slack
  # ID, but a legacy document can only ever back one signature. A second account that proves control
  # of the address the signature was settled on, by its verified account email or a passed challenge,
  # has met the same bar the first claim did, so it is covered by that signature instead of turned
  # away as already_claimed. Only approved signatures are shared.
  class Link
    class << self
      def linkable?(signature, user, email)
        signature&.legacy? && signature.approved? && signature.user_id != user.id &&
          email.present? && signature.legacy_signer_email.to_s.strip.casecmp?(email.to_s.strip)
      end

      def settle!(import, signature, via:)
        import.transaction do
          signature.nda_signature_links.create!(user: import.user, legacy_nda_import: import, proven_via: via)
          import.update!(state: "approved")
        end
        ImportMailer.settled(import)
        import
      rescue ActiveRecord::RecordNotUnique
        Claim.reject!(import, "already_claimed")
      end
    end
  end
end
