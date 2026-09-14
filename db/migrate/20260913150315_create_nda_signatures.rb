class CreateNdaSignatures < ActiveRecord::Migration[8.1]
  def change
    create_table :nda_signatures do |t|
      t.references :user, null: false, foreign_key: true
      t.string :document_version, null: false
      t.string :document_sha256, null: false
      t.string :signed_name, null: false
      t.datetime :signed_at, null: false
      t.string :ip_address
      t.text :user_agent
      t.text :transcript
      t.decimal :validation_score, precision: 5, scale: 4

      t.timestamps
    end

    add_index :nda_signatures, %i[user_id document_version], unique: true
  end
end
