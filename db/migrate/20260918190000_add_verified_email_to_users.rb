class AddVerifiedEmailToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :verified_email, :string
    execute <<~SQL.squish
      UPDATE users
      SET verified_email = LOWER(TRIM(email))
      WHERE email IS NOT NULL
    SQL
  end

  def down
    remove_column :users, :verified_email
  end
end
