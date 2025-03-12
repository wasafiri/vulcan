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

## Debugging

Email delivery and tracking issues can be debugged by:

1. Checking the logs for "POSTMARK PAYLOAD" entries
2. Using the `UpdateEmailStatusJob` to manually check status
3. Examining the notification records for tracking information

## Integration With Other Email Types

To add tracking to other types of emails:

1. Create a notification record with appropriate metadata
2. Pass the notification to the mailer
3. Update the mailer to capture the message ID
4. Schedule the `UpdateEmailStatusJob` to check the delivery status
