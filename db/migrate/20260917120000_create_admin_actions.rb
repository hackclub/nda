class CreateAdminActions < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_actions do |t|
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.references :target_user, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.text :reason
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end

    add_index :admin_actions, %i[subject_type subject_id]
    add_index :admin_actions, :created_at
  end
end
