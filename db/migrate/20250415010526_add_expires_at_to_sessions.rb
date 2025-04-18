class AddExpiresAtToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :expires_at, :datetime
    add_index :sessions, :expires_at
  end
end
