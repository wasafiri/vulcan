class AddEmailTrackingToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :message_id, :string
    add_column :notifications, :delivery_status, :string
    add_column :notifications, :delivered_at, :datetime
    add_column :notifications, :opened_at, :datetime

    add_index :notifications, :message_id
  end
end
