class RenameAdminTypeToAdministrator < ActiveRecord::Migration[8.0]
  def up
    # Update existing records
    execute("UPDATE users SET type = 'Administrator' WHERE type = 'Admin'")
  end

  def down
    # Revert the changes
    execute("UPDATE users SET type = 'Admin' WHERE type = 'Administrator'")
  end
end
