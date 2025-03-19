namespace :notification_tracking do
  desc "Backfill delivery status for existing medical certification requests"
  task :backfill, [:fix_duplicates, :app_id] => :environment do |_t, args|
    # Parse arguments
    fix_duplicates = args[:fix_duplicates].to_s.downcase == 'true'
    application_id = args[:app_id]
    dry_run = ENV['DRY_RUN'].to_s.downcase == 'true'
    
    # Build the query for notifications
    query = Notification.where(action: "medical_certification_requested")
    
    if application_id.present?
      puts "Targeting only Application ##{application_id}"
      query = query.where(notifiable_type: "Application", notifiable_id: application_id)
    end
    
    # First pass - identify notifications without message IDs
    backfill_query = query.where(message_id: nil)
    total_backfill = backfill_query.count
    puts "Found #{total_backfill} notifications without message IDs to process"
    
    # Check for duplicates across all applications
    if fix_duplicates || dry_run
      puts "Checking for potential duplicate notifications..."
      
      # Group notifications by application
      duplicate_counts = {}
      app_notifications = query.group_by { |n| n.notifiable_id }
      
      app_notifications.each do |app_id, notifications|
        next unless app_id && notifications.first.notifiable.is_a?(Application)
        
        # Count notifications per request_count for this application
        request_count_map = {}
        notifications.each do |notification|
          if notification.metadata.present? && notification.metadata['request_count'].present?
            count = notification.metadata['request_count'].to_i
            request_count_map[count] ||= []
            request_count_map[count] << notification.id
          end
        end
        
        # Find duplicate request counts
        app_duplicates = request_count_map.select { |_, ids| ids.size > 1 }
        if app_duplicates.any?
          duplicate_counts[app_id] = app_duplicates
          puts "Application ##{app_id}: Has duplicate notifications for request counts: #{app_duplicates.keys.join(', ')}"
          
          # Fix duplicates if requested
          if fix_duplicates && !dry_run
            puts "Fixing duplicates for Application ##{app_id}..."
            total_removed = fix_duplicates_for_app(app_id, app_duplicates, notifications)
            puts "Removed #{total_removed} duplicate notifications for Application ##{app_id}"
          end
        end
      end
      
      puts "Found duplicates in #{duplicate_counts.keys.size} applications" if duplicate_counts.any?
      puts 'DRY RUN - No changes were made' if dry_run && duplicate_counts.any?
    end
    
    # Skip actual backfill if this is just a dry run
    if dry_run
      puts "DRY RUN - Skipping backfill operation"
      return
    end
    
    # Process backfill
    processed = 0
    backfill_query.find_each do |notification|
      processed += 1
      print "Processing notification #{processed}/#{total_backfill}... "
      
      # Skip if the notification doesn't have the right metadata
      if !notification.notifiable.is_a?(Application)
        puts "SKIPPED (not an application)"
        next
      end
      
      application = notification.notifiable
      if !application.medical_provider_email.present?
        puts "SKIPPED (no provider email)"
        next
      end

      # Set a placeholder message ID so we can identify these later
      placeholder_id = "backfilled-#{notification.id}-#{Time.current.to_i}"
      notification.update(
        message_id: placeholder_id,
        delivery_status: 'unknown'
      )

      puts 'UPDATED with placeholder ID'
    end

    puts "Backfill complete. Added placeholder message IDs to #{processed} notifications."
    puts "These notifications will show 'Unknown' delivery status in the UI."
  end

  desc 'Check status of all tracked emails'
  task check_all: :environment do
    puts 'Scheduling status checks for all tracked medical certification emails...'

    # Find all notifications with message IDs
    notifications = Notification.where(
      action: "medical_certification_requested"
    ).where.not(message_id: nil)

    count = 0
    notifications.find_each do |notification|
      # Skip placeholder message IDs
      if notification.message_id.start_with?("backfilled-")
        next
      end

      # Schedule an update job
      UpdateEmailStatusJob.perform_later(notification.id)
      count += 1
    end

    puts "Scheduled #{count} status check jobs. Check the logs for results."
  end

  desc 'Fix duplicate notifications for a specific application'
  task :fix_duplicates, [:app_id] => :environment do |_t, args|
    app_id = args[:app_id]
    if app_id.blank?
      puts 'ERROR: Application ID is required'
      puts 'Usage: rails notification_tracking:fix_duplicates[123]'
      return
    end

    begin
      Application.find(app_id)
    rescue ActiveRecord::RecordNotFound
      puts "ERROR: Application ##{app_id} not found"
      return
    end

    puts "Fixing duplicate notifications for Application ##{app_id}"
    Rake::Task['notification_tracking:backfill'].invoke('true', app_id)
  end

  desc 'Analyze notification consistency for an application'
  task :analyze, [:app_id] => :environment do |_t, args|
    app_id = args[:app_id]
    if app_id.blank?
      puts 'ERROR: Application ID is required'
      puts 'Usage: rails notification_tracking:analyze[123]'
      return
    end

    ENV['DRY_RUN'] = 'true'
    Rake::Task['notification_tracking:backfill'].invoke('true', app_id)
  end

  private

  def fix_duplicates_for_app(app_id, duplicate_counts, notifications)
    total_removed = 0

    duplicate_counts.each do |count, ids|
      # Get the actual notification objects
      count_notifications = notifications.select { |n| ids.include?(n.id) }
      puts "Request count #{count}: #{count_notifications.size} notifications"

      # Sort by message_id (non-backfilled first, then by created_at)
      sorted_notifications = count_notifications.sort_by do |n|
        [n.message_id&.start_with?('backfilled-') ? 1 : 0, n.created_at]
      end

      # Keep the first notification (either non-backfilled or oldest)
      keep = sorted_notifications.first
      remove = sorted_notifications[1..-1]

      puts "  Keeping: ID #{keep.id} (#{keep.message_id})"
      puts "  Removing: #{remove.map(&:id).join(', ')}"

      # Remove duplicates
      begin
        ids_to_remove = remove.map(&:id)
        Notification.where(id: ids_to_remove).delete_all
        total_removed += ids_to_remove.size
        puts "  Removed #{ids_to_remove.size} duplicate notifications"
      rescue StandardError => e
        puts "  ERROR removing duplicates: #{e.message}"
      end
    end

    # Verify application counter matches notification count
    begin
      application = Application.find(app_id)
      notifications_after = Notification.where(
        notifiable_type: 'Application',
        notifiable_id: app_id,
        action: 'medical_certification_requested'
      ).count

      if application.medical_certification_request_count != notifications_after
        puts "Updating application request_count from #{application.medical_certification_request_count} to #{notifications_after}"
        application.update_columns(medical_certification_request_count: notifications_after)
        puts 'Application counter updated'
      else
        puts "Application counter is already correct: #{application.medical_certification_request_count}"
      end
    rescue StandardError => e
      puts "ERROR checking application counter: #{e.message}"
    end

    total_removed
  end
end
