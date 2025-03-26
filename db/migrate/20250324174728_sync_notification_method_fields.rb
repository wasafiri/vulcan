class SyncNotificationMethodFields < ActiveRecord::Migration[8.0]
  def up
    # Before removing the column, check if any records have communication_preference=0 (email)
    # but have letters in print queue
    execute <<-SQL
      UPDATE users
      SET communication_preference = 1
      FROM print_queue_items
      WHERE users.id = print_queue_items.constituent_id
        AND users.communication_preference = 0
        AND users.type = 'Constituent';
    SQL
    
    # Remove the notification_method column as it's redundant with communication_preference
    remove_column :users, :notification_method
  end

  def down
    # Add back the notification_method column if we need to roll back
    add_column :users, :notification_method, :integer
    
    # Set notification_method based on communication_preference for consistency
    execute <<-SQL
      UPDATE users
      SET notification_method = communication_preference
      WHERE type = 'Constituent';
    SQL
  end
end
