class AddSignatureTypeToNdaSignatures < ActiveRecord::Migration[8.1]
  def up
    add_column :nda_signatures, :signature_type, :string, null: false, default: "native"
    execute "UPDATE nda_signatures SET signature_type = 'native'"
    add_index :nda_signatures, :signature_type
  end

  def down
    remove_column :nda_signatures, :signature_type
  end
end
