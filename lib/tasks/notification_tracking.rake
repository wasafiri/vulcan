namespace :notification_tracking do
  desc "Backfill delivery status for existing medical certification requests"
  task backfill: :environment do
    # Find all medical certification requests without message IDs
    notifications = Notification.where(
      action: "medical_certification_requested",
      message_id: nil
    )
    
    total = notifications.count
    puts "Found #{total} notifications to process"
    
    processed = 0
    notifications.find_each do |notification|
      processed += 1
      print "Processing notification #{processed}/#{total}... "
      
      # Skip if the notification doesn't have the right metadata
      unless notification.notifiable.is_a?(Application) && 
             notification.metadata&.dig("provider_email").present?
        puts "SKIPPED (missing data)"
        next
      end
      
      # Set a placeholder message ID so we can identify these later
      placeholder_id = "backfilled-#{notification.id}-#{Time.current.to_i}"
      notification.update(
        message_id: placeholder_id,
        delivery_status: "unknown"
      )
      
      puts "UPDATED with placeholder ID"
    end
    
    puts "Backfill complete. Added placeholder message IDs to #{processed} notifications."
    puts "These notifications will show 'Unknown' delivery status in the UI."
  end
  
  desc "Check status of all tracked emails"
  task check_all: :environment do
    puts "Scheduling status checks for all tracked medical certification emails..."
    
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
end
