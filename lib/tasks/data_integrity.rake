namespace :data_integrity do
  desc "Find and report orphaned applications (applications without valid users)"
  task find_orphaned_applications: :environment do
    # Find applications with nil user_id
    nil_user_apps = Application.where(user_id: nil)

    # Find applications with invalid user_id (user doesn't exist)
    valid_user_ids = User.pluck(:id)
    invalid_user_apps = Application.where.not(user_id: valid_user_ids)

    # Combine the results
    orphaned_apps = nil_user_apps + invalid_user_apps

    if orphaned_apps.any?
      puts "Found #{orphaned_apps.count} orphaned applications:"
      orphaned_apps.each do |app|
        puts "  Application ID: #{app.id}, User ID: #{app.user_id || 'nil'}, Created: #{app.created_at}"
      end
    else
      puts "No orphaned applications found."
    end
  end

  desc "Fix orphaned applications by assigning them to a default user or deleting them"
  task :fix_orphaned_applications, [ :action, :default_user_email ] => :environment do |t, args|
    action = args[:action] || "report"
    default_user_email = args[:default_user_email]

    unless [ "report", "delete", "assign" ].include?(action)
      puts "Invalid action. Use 'report', 'delete', or 'assign'."
      exit
    end

    if action == "assign" && default_user_email.blank?
      puts "Default user email is required for 'assign' action."
      exit
    end

    # Find orphaned applications
    nil_user_apps = Application.where(user_id: nil)
    valid_user_ids = User.pluck(:id)
    invalid_user_apps = Application.where.not(user_id: valid_user_ids)
    orphaned_apps = nil_user_apps + invalid_user_apps

    if orphaned_apps.empty?
      puts "No orphaned applications found."
      exit
    end

    puts "Found #{orphaned_apps.count} orphaned applications."

    case action
    when "report"
      # Already reported above
    when "delete"
      puts "Deleting #{orphaned_apps.count} orphaned applications..."
      orphaned_apps.each do |app|
        puts "  Deleting Application ID: #{app.id}"
        app.destroy
      end
      puts "Deletion complete."
    when "assign"
      # Find or create the default user
      default_user = User.find_by(email: default_user_email)

      if default_user.nil?
        puts "User with email '#{default_user_email}' not found."
        exit
      end

      puts "Assigning #{orphaned_apps.count} orphaned applications to user #{default_user.id} (#{default_user.email})..."

      orphaned_apps.each do |app|
        puts "  Assigning Application ID: #{app.id} to User ID: #{default_user.id}"
        app.update(user_id: default_user.id)
      end

      puts "Assignment complete."
    end
  end
end
