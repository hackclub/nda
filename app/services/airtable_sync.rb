class AirtableSync
  VIDEO_FIELD = "Video".freeze
  AGREEMENT_FIELD = "Signed NDA".freeze
  SOURCES = { "native" => "nda.hackclub.com", "legacy" => "old system" }.freeze

  class << self
    def call(signature)
      user = signature.user
      fields = fields(signature, user)
      existing = signature.airtable_record_id.presence || locate(user)
      record_id = (existing ? AirtableClient.update(existing, fields) : AirtableClient.create(fields)).fetch("id")
      attachments(signature, record_id)
      signature.update!(airtable_record_id: record_id, airtable_synced_at: Time.current)
    end

    private

    def locate(user)
      by("{Slack ID} = #{AirtableClient.quote(user.slack_id)}") ||
        by("LOWER({Email}) = #{AirtableClient.quote(user.email.to_s.strip.downcase)}")
    end

    def by(filter) = AirtableClient.records(filter: filter, fields: [ "Email" ], max_records: 1).dig(0, "id")

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

      attach_agreement(signature, record_id) if signature.native?
      attach_video(signature, record_id)
    end

    def attach_agreement(signature, record_id)
      AirtableClient.upload_attachment(
        record_id,
        field: AGREEMENT_FIELD,
        bytes: NdaPdf.call(signature),
        filename: NdaPdf.filename(signature),
        content_type: "application/pdf"
      )
    end

    def attach_video(signature, record_id)
      blob = signature.identity_video.blob
      return if blob.nil? || signature.identity_video_purged_at?
      return Rails.logger.info("Signature #{signature.id}: video is #{blob.byte_size} bytes, too big for Airtable.") if
        blob.byte_size > AirtableClient::MAX_ATTACHMENT_BYTES

      AirtableClient.upload_attachment(
        record_id,
        field: VIDEO_FIELD,
        bytes: SseCustomerBlob.download(blob),
        filename: blob.filename.to_s,
        content_type: blob.content_type
      )
    rescue SseCustomerBlob::Error, ActiveStorage::FileNotFoundError => error
      Rails.logger.warn("Signature #{signature.id}: video unreadable for Airtable sync (#{error.class}).")
    end
  end
end
