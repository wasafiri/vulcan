class AddPhoneTypeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone_type, :string, default: 'voice'
    add_index :users, :phone_type
  end
end
