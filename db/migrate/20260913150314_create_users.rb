class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :hack_club_identity_id, null: false
      t.string :slack_id, null: false
      t.string :first_name
      t.string :last_name
      t.string :email

      t.timestamps
    end
    add_index :users, :hack_club_identity_id, unique: true
    add_index :users, :slack_id, unique: true
  end
end
