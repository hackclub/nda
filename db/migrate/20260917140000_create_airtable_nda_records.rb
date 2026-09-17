class CreateAirtableNdaRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :airtable_nda_records do |t|
      t.string :airtable_record_id, null: false
      t.string :email, null: false
      t.string :normalized_email, null: false
      t.string :signer_name
      t.datetime :signed_at, null: false

      t.timestamps
    end

    add_index :airtable_nda_records, :airtable_record_id, unique: true
    add_index :airtable_nda_records, [ :normalized_email, :signed_at ]

    create_table :airtable_nda_backfills do |t|
      t.datetime :completed_at, null: false

      t.timestamps
    end
  end
end
