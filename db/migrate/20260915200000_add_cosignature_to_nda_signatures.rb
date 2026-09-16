class AddCosignatureToNdaSignatures < ActiveRecord::Migration[8.1]
  def change
    change_table :nda_signatures, bulk: true do |t|
      t.string :cosigner_token_digest
      t.datetime :cosigner_token_expires_at
      t.datetime :cosigner_invited_at
      t.datetime :cosigner_reminded_at
      t.datetime :cosigner_signed_at
      t.string :cosigner_signed_name
      t.string :cosigner_ip_address
      t.text :cosigner_user_agent
    end

    add_index :nda_signatures, :cosigner_token_digest, unique: true,
      where: "cosigner_token_digest IS NOT NULL"
  end
end
