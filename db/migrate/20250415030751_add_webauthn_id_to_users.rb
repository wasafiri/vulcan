class AddWebauthnIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :webauthn_id, :string
    add_index :users, :webauthn_id, unique: true
  end
end
