class AddAirtableSyncStatusToNdaSignatures < ActiveRecord::Migration[8.1]
  def change
    add_column :nda_signatures, :airtable_agreement_attached_at, :datetime
    add_column :nda_signatures, :airtable_video_attached_at, :datetime
    add_column :nda_signatures, :airtable_sync_attempts, :integer, default: 0, null: false
    add_column :nda_signatures, :airtable_sync_error, :string
    add_column :nda_signatures, :airtable_sync_failed_at, :datetime
  end
end
