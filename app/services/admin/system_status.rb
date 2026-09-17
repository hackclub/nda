module Admin
  class SystemStatus
    Status = Data.define(:name, :state, :detail)

    def self.call(check_airtable: false)
      new(check_airtable:).call
    end

    def initialize(check_airtable:)
      @check_airtable = check_airtable
    end

    def call
      [ database, queue, airtable, configuration ]
    end

    private

    attr_reader :check_airtable

    def database
      ApplicationRecord.connection.select_value("SELECT 1")
      Status.new(name: "Database", state: :ok, detail: "Connected")
    rescue ActiveRecord::ActiveRecordError
      Status.new(name: "Database", state: :error, detail: "Unavailable")
    end

    def queue
      failures = SolidQueue::FailedExecution.count
      return Status.new(name: "Job queue", state: :warning, detail: "#{failures} failed job#{'s' unless failures == 1}") if failures.positive?

      Status.new(name: "Job queue", state: :ok, detail: "No failed jobs")
    rescue ActiveRecord::ActiveRecordError, NameError
      Status.new(name: "Job queue", state: :warning, detail: "Status unavailable")
    end

    def airtable
      return Status.new(name: "Airtable", state: :warning, detail: "Not configured") unless AirtableClient.configured?
      return Status.new(name: "Airtable", state: :ok, detail: "Configured") unless check_airtable

      AirtableClient.records(filter: "TRUE()", fields: [ "Email" ], max_records: 1)
      Status.new(name: "Airtable", state: :ok, detail: "Live connection passed")
    rescue AirtableClient::Error
      Status.new(name: "Airtable", state: :error, detail: "Live connection failed")
    end

    def configuration
      missing = required_configuration.reject { ENV[_1].present? }
      return Status.new(name: "Core services", state: :ok, detail: "Configured") if missing.empty?

      Status.new(name: "Core services", state: :warning, detail: "Missing #{missing.to_sentence}")
    end

    def required_configuration
      %w[HACK_CLUB_CLIENT_ID HACK_CLUB_CLIENT_SECRET XAI_API_KEY]
    end
  end
end
