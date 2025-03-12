# Email Tracking Guide

## Overview

This guide explains how email tracking works in the application, particularly for medical certification requests. The implementation provides detailed tracking of email delivery status, including when emails are delivered and opened by recipients.

## Implementation

### Database Schema

Email tracking information is stored in the `notifications` table with the following fields:

- `message_id`: Unique Postmark message ID for tracking
- `delivery_status`: Current status (e.g., "Delivered", "Opened", "error")
- `delivered_at`: When the email was successfully delivered
- `opened_at`: When the email was first opened
- `metadata`: JSON column storing additional information like browser and location

### Service Layer

The email tracking implementation is handled primarily through the `MedicalCertificationService`:

```ruby
# in app/services/applications/medical_certification_service.rb
def request_certification
  # ...
  notification = create_notification(current_time)
  send_email(notification)
  # ...
end
```

The notification is created with metadata and passed to the email job, which then provides the notification to the mailer for tracking.

### Email Job

The `MedicalCertificationEmailJob` accepts a notification ID parameter:

```ruby
MedicalCertificationEmailJob.perform_later(
  application_id: application.id, 
  timestamp: timestamp.iso8601,
  notification_id: notification&.id
)
```

### Mailer Integration

The mailer records the Postmark message ID when the email is sent:

```ruby
# in MedicalProviderMailer
def request_certification(application, notification = nil)
  # ...
  # After delivery, the Postmark message ID is captured and stored
  # ...
end
```

### UI Components

The certification history modal displays email status information:

- Delivery status badges
- Timestamps for delivery and opens
- Device and location information for opened emails

### Backfill Task

A rake task is provided for backfilling tracking data for existing notifications:

```
rails notification_tracking:backfill
```

## Postmark Configuration Requirements

For email tracking to work correctly, you need:

1. **API Token**: Set the `POSTMARK_API_TOKEN` environment variable with a valid Postmark API token that has permission to access message analytics.

2. **Open Tracking**: Ensure that open tracking is enabled in your Postmark account settings. This feature is now enabled in our application's configuration:

   ```ruby
   # in config/initializers/postmark_format.rb
   def postmark_settings
     {
       return_response: true,
       track_opens: true,  # Must be true to enable open tracking
       track_links: "none"
     }
   end
   ```

3. **Webhook Setup** (Optional): For real-time updates, you can configure Postmark webhooks to notify your application about delivery events. See Postmark documentation for details.

## Debugging

Email delivery and tracking issues can be debugged by:

1. Checking the logs for "POSTMARK PAYLOAD" entries
2. Using the `UpdateEmailStatusJob` to manually check status
3. Examining the notification records for tracking information

## Handling Duplicate Notifications

When the backfill task is run, it may create duplicate notification records with placeholder message IDs in the format `backfilled-ID-TIMESTAMP`. This can result in a discrepancy between:

1. The actual number of emails sent (tracked in `Application.medical_certification_request_count`)
2. The number of notification records in the database

To prevent this:

- The `MedicalCertificationService` now includes duplicate detection logic that checks for existing notifications with the same request count
- For applications with existing duplicates, run the fix task:
  ```
  rails notification_tracking:fix_duplicates[APPLICATION_ID]
  ```

The fix task will:
1. Identify notifications with duplicate request counts
2. Keep the notification with a real (non-backfilled) message ID if available, otherwise keep the oldest
3. Remove duplicate notifications
4. Ensure the application's `medical_certification_request_count` matches the actual notification count

You can also use the diagnostic task to analyze discrepancies without making changes:
```
rails notification_tracking:analyze[APPLICATION_ID]
```

## Integration With Other Email Types

To add tracking to other types of emails:

1. Create a notification record with appropriate metadata
2. Pass the notification to the mailer
3. Update the mailer to capture the message ID
4. Schedule the `UpdateEmailStatusJob` to check the delivery status
