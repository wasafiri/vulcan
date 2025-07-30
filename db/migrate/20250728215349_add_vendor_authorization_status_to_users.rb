class AddVendorAuthorizationStatusToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :vendor_authorization_status, :integer

    # Migrate existing vendor status data
    # pending: 0 -> pending: 0
    # approved: 1 -> approved: 1
    # suspended: 2 -> suspended: 2
    execute <<-SQL.squish
      UPDATE users
      SET vendor_authorization_status = status
      WHERE type = 'Users::Vendor'
    SQL

    # Update vendors to use base user status for authentication
    # pending -> inactive (0), approved -> active (1), suspended -> suspended (2)
    execute <<-SQL
      UPDATE users
      SET status = CASE
        WHEN status = 0 THEN 0  -- pending -> inactive
        WHEN status = 1 THEN 1  -- approved -> active
        WHEN status = 2 THEN 2  -- suspended -> suspended
        ELSE status
      END
      WHERE type = 'Users::Vendor'
    SQL
  end

  def down
    # Restore original vendor status from vendor_authorization_status
    execute <<-SQL.squish
      UPDATE users
      SET status = vendor_authorization_status
      WHERE type = 'Users::Vendor' AND vendor_authorization_status IS NOT NULL
    SQL

    remove_column :users, :vendor_authorization_status
  end
end
