class AddW9StatusToVendors < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :w9_status, :integer, default: 0, null: false
    add_column :users, :w9_rejections_count, :integer, default: 0, null: false
    add_column :users, :last_w9_reminder_sent_at, :datetime

    add_index :users, :w9_status, where: "type = 'Vendor'"
    add_index :users, :w9_rejections_count, where: "type = 'Vendor'"
  end
end
