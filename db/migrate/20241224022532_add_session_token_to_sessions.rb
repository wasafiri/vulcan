class AddSessionTokenToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :session_token, :string
    add_column :sessions, :failed_attempts, :integer, default: 0

    add_index :sessions, :session_token, unique: true
  end
end
