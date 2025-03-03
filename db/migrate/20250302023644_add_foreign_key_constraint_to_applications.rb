class AddForeignKeyConstraintToApplications < ActiveRecord::Migration[8.0]
  def up
    # First, identify any orphaned applications (those with nil user_id or invalid user_id)
    orphaned_applications = execute(<<-SQL).to_a
      SELECT applications.id, applications.user_id
      FROM applications
      LEFT JOIN users ON applications.user_id = users.id
      WHERE applications.user_id IS NULL OR users.id IS NULL
    SQL

    if orphaned_applications.any?
      # Log the orphaned applications
      puts "Found #{orphaned_applications.size} orphaned applications:"
      orphaned_applications.each do |app|
        puts "  Application ID: #{app['id']}, User ID: #{app['user_id'] || 'nil'}"
      end

      # Option 1: Delete orphaned applications
      # execute("DELETE FROM applications WHERE id IN (#{orphaned_applications.map { |a| a['id'] }.join(',')})")

      # Option 2: Assign orphaned applications to a default user (create one if needed)
      # This is commented out as it requires a default user to exist
      # default_user_id = User.find_or_create_by!(email: 'system@example.com', type: 'Constituent').id
      # orphaned_applications.each do |app|
      #   execute("UPDATE applications SET user_id = #{default_user_id} WHERE id = #{app['id']}")
      # end

      # For now, we'll just raise an error to prevent the migration from proceeding
      # until the orphaned applications are handled manually
      raise "Cannot add foreign key constraint: orphaned applications exist. Please fix them manually."
    end

    # Check if the foreign key already exists
    if !foreign_key_exists?(:applications, :users)
      # Only add the foreign key if it doesn't exist
      add_foreign_key :applications, :users, on_delete: :restrict
    else
      puts "Foreign key from applications to users already exists. Skipping creation."
    end
  end

  def down
    if foreign_key_exists?(:applications, :users)
      remove_foreign_key :applications, :users
    else
      puts "Foreign key from applications to users does not exist. Skipping removal."
    end
  end
end
