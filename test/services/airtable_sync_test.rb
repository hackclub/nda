require "test_helper"
require_relative "../support/airtable_stub"

class AirtableSyncTest < ActiveSupport::TestCase
  include AirtableStub

  READ_ONLY = [ "Signed?", "Signed NDA", "Signed NDA - Last Modified At",
                "Loops - ndaRequestedAt", "Loops - ndaCompletedAt" ].freeze

  setup do
    @user = users(:one)
    @signature = create_signature(@user, signed_at: Time.utc(2026, 3, 4, 5, 6))
  end

  test "creates a row when nobody in the base matches" do
    fake = with_airtable { AirtableSync.call(@signature) }

    fields = fake.created.sole
    assert_equal @user.slack_id, fields["Slack ID"]
    assert_equal "nda.hackclub.com", fields["Source"]
    assert_equal "2026-03-04T05:06:00Z", fields["Signed At"]
    assert_equal "ada@example.com", fields["Email"]
    assert_equal "1990-01-01", fields["Date of Birth"]
    assert_equal "VT", fields["State"]
    assert_equal "05482", fields["ZIP"]
    assert_empty fake.updated
    assert_equal "rec1new", @signature.reload.airtable_record_id
    assert @signature.airtable_synced_at.present?
  end

  test "updates the member's existing row instead of duplicating them" do
    row = { id: "recOld", "Email": "ada@example.com" }
    fake = with_airtable(rows: [ row ]) { AirtableSync.call(@signature) }

    assert_empty fake.created
    assert_equal "recOld", fake.updated.sole.first
    assert_equal "recOld", @signature.reload.airtable_record_id
  end

  test "moves an existing row from the same user's legacy signature to their current signature" do
    legacy = create_legacy_signature(@user, airtable_record_id: "recOld", airtable_synced_at: 1.year.ago)
    row = { id: "recOld", "Email": "ada@example.com" }

    fake = with_airtable(rows: [ row ]) { AirtableSync.call(@signature) }

    assert_equal "recOld", fake.updated.sole.first
    assert_nil legacy.reload.airtable_record_id
    assert_equal "recOld", @signature.reload.airtable_record_id
    assert @signature.airtable_synced_at.present?
  end

  test "refuses to write to a row linked to another user" do
    create_legacy_signature(users(:two), airtable_record_id: "recOld")
    row = { id: "recOld", "Email": "ada@example.com" }
    fake = nil

    error = assert_raises(AirtableClient::Error) do
      with_airtable(rows: [ row ]) do |airtable|
        fake = airtable
        AirtableSync.call(@signature)
      end
    end

    assert_match(/another user/, error.message)
    assert_empty fake.updated
    assert_empty fake.attachments
    assert_nil @signature.reload.airtable_record_id
  end

  test "prefers a row already carrying the member's Slack ID" do
    rows = [ { id: "recEmail", "Email": "ada@example.com" },
             { id: "recSlack", "Email": "other@example.com", "Slack ID": @user.slack_id } ]
    fake = with_airtable(rows: rows) { AirtableSync.call(@signature) }

    assert_equal "recSlack", fake.updated.sole.first
  end

  test "never writes a formula or computed field" do
    fake = with_airtable { AirtableSync.call(@signature) }

    assert_empty fake.created.sole.keys & READ_ONLY
  end

  test "sends a video Airtable will accept" do
    fake = with_airtable { AirtableSync.call(@signature) }

    attachment = fake.attachments.find { _1[:field] == "Video" }
    assert_equal "video/webm", attachment[:content_type]
    assert_equal @signature.identity_video.blob.byte_size, attachment[:size]
  end

  test "attaches the agreement, which is what makes the row read as signed" do
    fake = with_airtable { AirtableSync.call(@signature) }

    agreement = fake.attachments.find { _1[:field] == "Signed NDA" }
    assert_equal "application/pdf", agreement[:content_type]
    assert_equal "Ada Lovelace - Hack Club Contributor NDA.pdf", agreement[:filename]
    assert agreement[:size].positive?
  end

  test "does not upload the same files twice on a later sync" do
    with_airtable { AirtableSync.call(@signature) }
    fake = with_airtable { AirtableSync.call(@signature.reload) }

    assert_empty fake.attachments
    assert_equal 1, fake.updated.size
  end

  test "a retry resumes after the last successful attachment" do
    first = nil
    assert_raises(AirtableClient::TransientError) do
      with_airtable do |airtable|
        first = airtable
        upload = airtable.method(:upload_attachment)
        airtable.define_singleton_method(:upload_attachment) do |record_id, **arguments|
          raise AirtableClient::TransientError, "temporary upload failure" if arguments[:field] == "Video"

          upload.call(record_id, **arguments)
        end
        AirtableSync.call(@signature)
      end
    end

    assert_equal [ "Signed NDA" ], first.attachments.map { _1[:field] }
    assert_equal "rec1new", @signature.reload.airtable_record_id
    assert @signature.airtable_agreement_attached_at?
    assert_not @signature.airtable_video_attached_at?

    second = with_airtable { AirtableSync.call(@signature.reload) }

    assert_equal [ "Video" ], second.attachments.map { _1[:field] }
    assert @signature.reload.airtable_synced_at?
  end

  test "leaves a video over Airtable's cap in R2 and still syncs the rest" do
    @signature.identity_video.purge
    @signature.identity_video.attach(
      io: StringIO.new("0" * (AirtableClient::MAX_ATTACHMENT_BYTES + 1)),
      filename: "big.webm", content_type: "video/webm"
    )
    fake = with_airtable { AirtableSync.call(@signature.reload) }

    assert_empty fake.attachments.select { _1[:field] == "Video" }
    assert_equal 1, fake.created.size
    assert @signature.reload.airtable_synced_at.present?
  end

  test "marks an imported signature as coming from the old system" do
    @signature.destroy!
    legacy = create_legacy_signature(@user)
    fake = with_airtable { AirtableSync.call(legacy) }

    assert_equal "old system", fake.created.sole["Source"]
    assert_empty fake.attachments, "an imported signature already has its own document in the base"
  end
end
