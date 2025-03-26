class AddNotificationMethodToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :notification_method, :integer
  end
end
