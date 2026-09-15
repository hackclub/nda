class AddAirtableCheckedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :airtable_checked_at, :datetime
  end
end
