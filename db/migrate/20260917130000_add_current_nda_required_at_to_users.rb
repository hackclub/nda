class AddCurrentNdaRequiredAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :current_nda_required_at, :datetime
  end
end
