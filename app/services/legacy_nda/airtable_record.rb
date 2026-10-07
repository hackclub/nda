require "net/http"

module LegacyNda
  class AirtableRecord
    FIELDS = [ "Email", "Legal First Name", "Legal Last Name", "Loops - ndaCompletedAt", "Signed NDA" ].freeze
    ATTACHMENT_HOSTS = %w[.airtableusercontent.com .airtable.com].freeze

    Found = Data.define(:id, :email, :name, :signed_at, :document_url, :document_filename, :document_bytes)
    class DocumentTooLarge < StandardError; end

    class << self
      # The local cache is a snapshot from the last backfill, so a miss is only final where a login
      # must not wait on Airtable (cached_only). A member asking us to look goes to the base, or
      # anyone who signed the old system after the snapshot could never be found.
      def signed_for(email, cached_only: false)
        address = email.to_s.strip.downcase
        return nil if address.blank?

        cached = AirtableNdaRecord.signed_for(address)
        return cached if cached
        return nil if AirtableNdaRecord.backfill_complete? && (cached_only || !AirtableClient.configured?)

        rows = AirtableClient.records(
          filter: "AND({Signed?}, LOWER({Email}) = #{AirtableClient.quote(address)})",
          fields: FIELDS,
          max_records: 10
        )
        rows.filter_map { |row| build(row) }.min_by(&:signed_at)
      end

      def all_signed
        AirtableClient.all_records(filter: "{Signed?}", fields: FIELDS).filter_map { |row| build(row) }
      end

      def find(record_id) = build(AirtableClient.record(record_id))

      def download(record)
        return nil if record.document_bytes.to_i > LegacyNdaImport::MAX_DOCUMENT_BYTES

        uri = URI(record.document_url.to_s)
        return nil unless uri.is_a?(URI::HTTPS) && uri.host.to_s.end_with?(*ATTACHMENT_HOSTS)

        bytes = +"".b
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 30) do |http|
          http.request(Net::HTTP::Get.new(uri)) do |response|
            next unless response.is_a?(Net::HTTPSuccess)

            response.read_body do |chunk|
              raise DocumentTooLarge if bytes.bytesize + chunk.bytesize > LegacyNdaImport::MAX_DOCUMENT_BYTES

              bytes << chunk
            end
          end
        end
        bytes.presence
      rescue DocumentTooLarge
        nil
      rescue URI::InvalidURIError, Timeout::Error, SocketError, SystemCallError => error
        Rails.logger.warn("Airtable document #{record.id} could not be fetched: #{error.class}")
        nil
      end

      private

      def build(row)
        fields = row["fields"].to_h
        signed_at = parse_time(fields["Loops - ndaCompletedAt"])
        return nil if signed_at.nil?

        attachment = Array(fields["Signed NDA"]).first.to_h
        Found.new(
          id: row["id"],
          email: fields["Email"].to_s.strip,
          name: [ fields["Legal First Name"], fields["Legal Last Name"] ].compact_blank.join(" "),
          signed_at: signed_at,
          document_url: attachment["url"],
          document_filename: attachment["filename"].presence || "legacy-nda.pdf",
          document_bytes: attachment["size"]
        )
      end

      def parse_time(value) = value.present? ? Time.zone.parse(value.to_s) : nil
    end
  end
end
