class AddSigningDetails < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :legal_first_name
      t.string :legal_last_name
      t.date :birthdate
      t.string :address_line_1
      t.string :address_line_2
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :country
    end

    change_table :nda_signatures, bulk: true do |t|
      t.string :cosigner_name
      t.string :cosigner_email
    end
  end
end
