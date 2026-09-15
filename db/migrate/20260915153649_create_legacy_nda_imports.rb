class CreateLegacyNdaImports < ActiveRecord::Migration[8.1]
  def change
    create_table :legacy_nda_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :nda_signature, foreign_key: true
      t.string :state, null: false, default: "pending"
      t.string :document_sha256
      t.string :envelope_id
      t.jsonb :reasons, null: false, default: []
      t.jsonb :verification
      t.string :challenge_digest
      t.string :challenge_email
      t.datetime :challenge_expires_at
      t.integer :challenge_attempts, null: false, default: 0
      t.string :ip_address
      t.datetime :document_purged_at
      t.timestamps
    end

    add_index :legacy_nda_imports, :state
    add_index :legacy_nda_imports, :created_at
    add_index :legacy_nda_imports, :document_sha256
  end
end
