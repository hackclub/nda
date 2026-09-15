class AddLegacyFieldsToNdaSignatures < ActiveRecord::Migration[8.1]
  def change
    change_table :nda_signatures, bulk: true do |t|
      t.string :verification_state, null: false, default: "approved"
      t.string :legacy_envelope_id
      t.string :legacy_document_sha256
      t.string :legacy_signing_certificate_fingerprint
      t.string :legacy_signer_email
      t.string :legacy_signer_name
      t.boolean :legacy_cosigner_present
      t.datetime :legacy_cosigner_signed_at
      t.jsonb :legacy_verification
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.text :review_note
    end

    add_index :nda_signatures, :legacy_envelope_id, unique: true, where: "legacy_envelope_id IS NOT NULL"
    add_index :nda_signatures, :legacy_document_sha256, unique: true, where: "legacy_document_sha256 IS NOT NULL"
    add_index :nda_signatures, :verification_state
  end
end
