# Email Delivery Tracking

This document explains how email delivery tracking works in the application, particularly for medical certification requests.

## Overview

The application now tracks the delivery status of emails sent to medical providers. This includes:

- When an email was sent
- Whether it was successfully delivered
- Whether it was opened by the recipient
- Details about the recipient's environment (browser, location, etc.)

This information is displayed in the Medical Certification Request History modal.

## Implementation Details

### Database

Email tracking information is stored in the `notifications` table with the following additional columns:

- `message_id`: The unique ID assigned by Postmark for tracking
- `delivery_status`: Current status of the email (e.g., "Delivered", "Opened", "error")
- `delivered_at`: When the email was successfully delivered
- `opened_at`: When the email was first opened by the recipient

Additional data like recipient's browser and location is stored in the `metadata` JSON column.

### How It Works

1. **Sending an Email**
   - When a medical certification request is sent, we track the Postmark message ID
   - This ID is stored in the associated notification record

2. **Tracking Delivery Status**
   - A background job (`UpdateEmailStatusJob`) periodically checks the status
   - Status updates are fetched from Postmark's API
   - The notification record is updated with the latest status

3. **User Interface**
   - Delivery status is shown in the certification history modal
   - Status indicators show whether emails were delivered or opened
   - Error messages are displayed for failed emails
   - Detailed information about opens (browser, location) is shown when available

## Manual Status Checks

Users can manually check the status of an email by clicking the "Check Status" button in the certification history modal. This triggers an immediate status check.

## Postmark Configuration

For email tracking to work, you need:

1. A valid Postmark API token in the `POSTMARK_API_TOKEN` environment variable
2. Message streams configured in your Postmark account
3. Open tracking enabled in your Postmark account settings

## Troubleshooting

Common issues:

- **Missing status information**: Ensure Postmark API token is correctly set
- **Delivery errors**: Check if the sender email is verified in Postmark
- **No open tracking data**: Ensure open tracking is enabled in Postmark

## Adding Tracking to Other Emails

To add tracking to other types of emails:

1. Pass a notification object to the mailer
2. Update the mailer to record the message ID
3. Schedule the `UpdateEmailStatusJob` to check the status
