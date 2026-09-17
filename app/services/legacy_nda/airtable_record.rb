require "net/http"

module LegacyNda
  class AirtableRecord
    FIELDS = [ "Email", "Legal First Name", "Legal Last Name", "Loops - ndaCompletedAt", "Signed NDA" ].freeze
    ATTACHMENT_HOSTS = %w[.airtableusercontent.com .airtable.com].freeze

    Found = Data.define(:id, :email, :name, :signed_at, :document_url, :document_filename, :document_bytes)

    class << self
      def signed_for(email)
        address = email.to_s.strip.downcase
        return nil if address.blank?

        cached = AirtableNdaRecord.signed_for(address)
        return cached if cached
        return nil if AirtableNdaRecord.backfill_complete?

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

        response = Net::HTTP.start(
          uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 30
        ) { |http| http.request(Net::HTTP::Get.new(uri)) }
        response.is_a?(Net::HTTPSuccess) ? response.body : nil
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
