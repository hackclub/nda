require "net/http"

class AirtableClient
  API = URI("https://api.airtable.com")
  CONTENT = URI("https://content.airtable.com")
  MAX_ATTACHMENT_BYTES = 5.megabytes

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class TransientError < Error; end

  class << self
    def configured? = ENV["AIRTABLE_TOKEN"].present? && base_id.present? && table_id.present?

    def quote(value) = %("#{value.to_s.gsub(/["\\]/) { |c| "\\#{c}" }}")

    def records(filter:, fields: nil, max_records: 10)
      query = [ [ "filterByFormula", filter ], [ "maxRecords", max_records ] ]
      query += Array(fields).map { |field| [ "fields[]", field ] }
      get("#{table_path}?#{URI.encode_www_form(query)}").fetch("records", [])
    end

    def all_records(filter:, fields: nil)
      Enumerator.new do |records|
        offset = nil
        loop do
          query = [ [ "filterByFormula", filter ], [ "pageSize", 100 ] ]
          query << [ "offset", offset ] if offset
          query += Array(fields).map { |field| [ "fields[]", field ] }
          page = get("#{table_path}?#{URI.encode_www_form(query)}")
          page.fetch("records", []).each { |record| records << record }
          offset = page["offset"]
          break if offset.blank?
        end
      end
    end

    def record(record_id) = get("#{table_path}/#{record_id}")

    def create(fields) = post(table_path, { fields: fields, typecast: true })

    def update(record_id, fields) = patch("#{table_path}/#{record_id}", { fields: fields, typecast: true })

    def update_many(records)
      records.each_slice(10).sum(0) do |slice|
        patch(table_path, { records: slice.map { |id, fields| { id: id, fields: fields } }, typecast: true })
        slice.size
      end
    end

    def upload_attachment(record_id, field:, bytes:, filename:, content_type:)
      if bytes.bytesize > MAX_ATTACHMENT_BYTES
        raise Error, "attachment is #{bytes.bytesize} bytes, over Airtable's #{MAX_ATTACHMENT_BYTES} limit"
      end

      post(
        "/v0/#{base_id}/#{record_id}/#{ERB::Util.url_encode(field)}/uploadAttachment",
        { contentType: content_type, filename: filename, file: Base64.strict_encode64(bytes) },
        host: CONTENT
      )
    end

    private

    def base_id = ENV["AIRTABLE_BASE_ID"]
    def table_id = ENV["AIRTABLE_TABLE_ID"]
    def table_path = "/v0/#{base_id}/#{table_id}"

    def get(path) = perform(Net::HTTP::Get.new(path, headers))

    def post(path, body, host: API) = perform(build(Net::HTTP::Post, path, body), host: host)

    def patch(path, body) = perform(build(Net::HTTP::Patch, path, body))

    def build(klass, path, body)
      klass.new(path, headers.merge("Content-Type" => "application/json")).tap { |r| r.body = JSON.generate(body) }
    end

    def headers
      raise ConfigurationError, "AIRTABLE_TOKEN, AIRTABLE_BASE_ID and AIRTABLE_TABLE_ID must be set" unless configured?

      { "Authorization" => "Bearer #{ENV.fetch("AIRTABLE_TOKEN")}", "Accept" => "application/json" }
    end

    def perform(request, host: API)
      response = Net::HTTP.start(
        host.host, host.port, use_ssl: true, open_timeout: 5, read_timeout: 30
      ) { |http| http.request(request) }
      parse_response(response)
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise TransientError, "Airtable is unavailable: #{error.message}"
    end

    def parse_response(response)
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

      code = response.code.to_i
      error_class = code == 429 || code >= 500 ? TransientError : Error
      raise error_class, "Airtable returned HTTP #{response.code}"
    rescue JSON::ParserError
      raise TransientError, "Airtable returned an invalid response"
    end
  end
end
