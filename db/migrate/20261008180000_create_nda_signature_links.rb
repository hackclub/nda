class CreateNdaSignatureLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :nda_signature_links do |t|
      t.references :nda_signature, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :legacy_nda_import, foreign_key: true
      t.string :proven_via, null: false
      t.timestamps
    end

    add_index :nda_signature_links, %i[nda_signature_id user_id], unique: true
  end
end
