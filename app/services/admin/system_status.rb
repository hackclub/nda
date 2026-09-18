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
      if failures.positive?
        airtable = SolidQueue::FailedExecution.joins(:job)
          .where(solid_queue_jobs: { class_name: "SyncSignatureToAirtableJob" }).count
        detail = "#{failures} failed job#{'s' unless failures == 1}"
        detail += " (#{airtable} Airtable sync)" if airtable.positive?
        return Status.new(name: "Job queue", state: :warning, detail: detail)
      end

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
      %w[
        HACK_CLUB_CLIENT_ID HACK_CLUB_CLIENT_SECRET HACK_CLUB_REDIRECT_URI XAI_API_KEY SLACK_BOT_TOKEN
        AIRTABLE_TOKEN AIRTABLE_BASE_ID AIRTABLE_TABLE_ID LOOPS_API_KEY
        LOOPS_IMPORT_CHALLENGE_TRANSACTIONAL_ID LOOPS_IMPORT_SETTLED_TRANSACTIONAL_ID
        LOOPS_IMPORT_REJECTED_TRANSACTIONAL_ID LOOPS_IMPORT_NEEDS_REVIEW_TRANSACTIONAL_ID
        LOOPS_SIGNATURE_RECEIPT_TRANSACTIONAL_ID LOOPS_COSIGN_REQUEST_TRANSACTIONAL_ID
        LOOPS_COSIGN_RECEIPT_TRANSACTIONAL_ID
      ]
    end
  end
end
