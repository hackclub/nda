class AirtableSync
  VIDEO_FIELD = "Video".freeze
  AGREEMENT_FIELD = "Signed NDA".freeze
  SOURCES = { "native" => "nda.hackclub.com", "legacy" => "old system" }.freeze

  class << self
    def call(signature)
      user = signature.user
      existing = signature.airtable_record_id.presence || locate(user)
      ensure_record_available!(signature, existing) if existing
      record_id = (existing ? AirtableClient.update(existing, fields(signature, user)) :
        AirtableClient.create(fields(signature, user))).fetch("id")
      persist_record_link!(signature, record_id)
      attachments(signature, record_id)
      signature.update!(airtable_synced_at: Time.current, airtable_sync_error: nil, airtable_sync_failed_at: nil)
    end

    private

    def locate(user)
      by("{Slack ID} = #{AirtableClient.quote(user.slack_id)}") ||
        by("LOWER({Email}) = #{AirtableClient.quote(user.verified_email.to_s.strip.downcase)}")
    end

    def by(filter) = AirtableClient.records(filter: filter, fields: [ "Email" ], max_records: 1).dig(0, "id")

    def ensure_record_available!(signature, record_id)
      owner = NdaSignature.find_by(airtable_record_id: record_id)
      return if owner.nil? || owner.id == signature.id || owner.user_id == signature.user_id

      raise AirtableClient::Error, "Airtable record is already linked to another user"
    end

    def persist_record_link!(signature, record_id)
      NdaSignature.transaction do
        owner = NdaSignature.lock.find_by(airtable_record_id: record_id)
        ensure_record_available!(signature, record_id) if owner
        owner.update!(airtable_record_id: nil) if owner && owner.id != signature.id
        signature.update!(airtable_record_id: record_id)
      end
    rescue ActiveRecord::RecordNotUnique
      raise AirtableClient::Error, "Airtable record was linked to another signature during sync"
    end

    def fields(signature, user)
      cosigner_first, cosigner_last = signature.cosigner_name.to_s.split(/\s+/, 2)
      {
        "Email" => user.email,
        "Legal First Name" => user.legal_first_name,
        "Legal Last Name" => user.legal_last_name,
        "Date of Birth" => user.birthdate&.iso8601,
        "Address Line 1" => user.address_line_1,
        "Address Line 2" => user.address_line_2,
        "City" => user.city,
        "State" => user.region,
        "ZIP" => user.postal_code,
        "Country" => user.country,
        "Co-Signer First Name" => cosigner_first,
        "Co-Signer Last Name" => cosigner_last,
        "Co-Signer Email" => signature.cosigner_email,
        "Video Transcription" => signature.transcript,
        "Slack ID" => user.slack_id,
        "Signed At" => signature.signed_at.iso8601,
        "Source" => SOURCES[signature.signature_type]
      }.compact_blank
    end

    def attachments(signature, record_id)
      return if signature.airtable_synced_at?

      attach_agreement(signature, record_id) if signature.native? && !signature.airtable_agreement_attached_at?
      attach_video(signature, record_id) unless signature.airtable_video_attached_at?
    end

    def attach_agreement(signature, record_id)
      AirtableClient.upload_attachment(
        record_id,
        field: AGREEMENT_FIELD,
        bytes: NdaPdf.call(signature),
        filename: NdaPdf.filename(signature),
        content_type: "application/pdf"
      )
      signature.update!(airtable_agreement_attached_at: Time.current)
    end

    def attach_video(signature, record_id)
      blob = signature.identity_video.blob
      return signature.update!(airtable_video_attached_at: Time.current) if blob.nil? || signature.identity_video_purged_at?
      if blob.byte_size > AirtableClient::MAX_ATTACHMENT_BYTES
        Rails.logger.info("Signature #{signature.id}: video is #{blob.byte_size} bytes, too big for Airtable.")
        return signature.update!(airtable_video_attached_at: Time.current)
      end

      AirtableClient.upload_attachment(
        record_id,
        field: VIDEO_FIELD,
        bytes: SseCustomerBlob.download(blob),
        filename: blob.filename.to_s,
        content_type: blob.content_type
      )
      signature.update!(airtable_video_attached_at: Time.current)
    rescue SseCustomerBlob::Error, ActiveStorage::FileNotFoundError => error
      Rails.logger.warn("Signature #{signature.id}: video unreadable for Airtable sync (#{error.class}).")
      signature.update!(airtable_video_attached_at: Time.current)
    end
  end
end
