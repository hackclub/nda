class AddIdentityVideoPurgedAtToNdaSignatures < ActiveRecord::Migration[8.1]
  def change
    add_column :nda_signatures, :identity_video_purged_at, :datetime
  end
end
