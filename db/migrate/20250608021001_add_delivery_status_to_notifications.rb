class AddDeliveryStatusToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :created_by_service, :boolean, default: false, null: false
    add_index :notifications, :created_by_service
    add_column :notifications, :audited, :boolean, default: false, null: false
    add_index :notifications, :audited
  end
end
