class AddAirtableSources < ActiveRecord::Migration[8.1]
  def change
    add_column :legacy_nda_imports, :source, :string, null: false, default: "upload"
    add_column :legacy_nda_imports, :airtable_record_id, :string
    add_index :legacy_nda_imports, :airtable_record_id

    add_column :nda_signatures, :legacy_source, :string
    add_column :nda_signatures, :airtable_record_id, :string
    add_column :nda_signatures, :airtable_synced_at, :datetime
    add_index :nda_signatures, :airtable_record_id, unique: true, where: "airtable_record_id IS NOT NULL"

    change_column_null :nda_signatures, :document_sha256, true
  end
end
