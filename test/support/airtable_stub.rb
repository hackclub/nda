# A small stand-in for the Airtable base. It parses the filter the code actually builds rather than
# accepting any call, so a malformed or unescaped formula fails the test.
module AirtableStub
  class Fake
    EMAIL = /LOWER\(\{Email\}\) = "((?:[^"\\]|\\.)*)"/
    SLACK = /\{Slack ID\} = "((?:[^"\\]|\\.)*)"/

    attr_reader :rows, :created, :updated, :attachments

    def initialize(rows)
      @rows = rows.map { |row| { "id" => row[:id], "fields" => row.except(:id).stringify_keys } }
      @created = []
      @updated = []
      @attachments = []
    end

    def records(filter:, fields: nil, max_records: 10)
      matched = rows
      matched = matched.select { |row| row.dig("fields", "Signed?") } if filter.include?("{Signed?}")
      matched = match(matched, filter, EMAIL) { |row| row.dig("fields", "Email").to_s.downcase }
      matched = match(matched, filter, SLACK) { |row| row.dig("fields", "Slack ID").to_s }
      matched.first(max_records)
    end

    def record(record_id) = rows.find { _1["id"] == record_id } || raise(AirtableClient::Error, "no such record")

    def create(fields)
      @created << fields
      { "id" => "rec#{created.size}new" }
    end

    def update(id, fields)
      @updated << [ id, fields ]
      { "id" => id }
    end

    def upload_attachment(record_id, field:, bytes:, filename:, content_type:)
      raise AirtableClient::Error, "too big" if bytes.bytesize > AirtableClient::MAX_ATTACHMENT_BYTES

      @attachments << { record_id:, field:, size: bytes.bytesize, filename:, content_type: }
      { "id" => record_id }
    end

    private

    def match(rows, filter, pattern)
      wanted = filter[pattern, 1]
      return rows if wanted.nil?

      unescaped = wanted.gsub(/\\(.)/, '\1')
      rows.select { |row| yield(row) == unescaped }
    end
  end

  def with_airtable(rows: [])
    fake = Fake.new(rows)
    singleton = AirtableClient.singleton_class
    stubbed = %i[records record create update upload_attachment]
    originals = (stubbed + [ :configured? ]).to_h { [ _1, singleton.instance_method(_1) ] }
    singleton.define_method(:configured?) { true }
    stubbed.each do |name|
      singleton.define_method(name) { |*args, **kwargs| fake.public_send(name, *args, **kwargs) }
    end
    yield fake
    fake
  ensure
    originals&.each { |name, method| singleton.define_method(name, method) }
  end
end
