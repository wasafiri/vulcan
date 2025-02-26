# Inbound Email Processing

This document explains how to set up and use the inbound email processing feature in the application. This feature allows constituents to submit proofs (income and residency) and medical providers to submit medical certifications via email.

## Overview

The application uses Rails' Action Mailbox to process incoming emails. When a constituent or medical provider sends an email to a designated address, the system:

1. Receives the email via a webhook from Postmark
2. Routes the email to the appropriate mailbox based on the recipient address
3. Processes the email and its attachments
4. Associates the attachments with the correct application
5. Updates the application status as needed
6. Notifies administrators of the new submission

## Setup

### 1. Configure Postmark

1. Log in to your [Postmark account](https://postmarkapp.com)
2. Navigate to your server settings
3. Go to the "Inbound" tab
4. Set up an inbound domain (e.g., `inbound.yourdomain.com`)
5. Configure the webhook URL to point to your application's Action Mailbox endpoint:
   ```
   https://yourdomain.com/rails/action_mailbox/postmark/inbound_emails
   ```
6. **Important**: Check the box labeled "Include raw email content in JSON payload"

### 2. Configure Action Mailbox

1. Set the inbound email hash in your credentials:

   ```bash
   bin/rails credentials:edit
   ```

   Add the following:

   ```yaml
   action_mailbox:
     ingress_password: your_secure_password_here
     postmark_api_key: your_postmark_api_key_here
   ```

2. Configure the inbound email hash in your initializer:

   ```ruby
   # config/initializers/action_mailbox.rb
   Rails.application.config.action_mailbox.ingress = :postmark
   ```

### 3. Set Up Email Addresses

The system is configured to route emails to different mailboxes based on the recipient address:

- **Proof submissions**: `proof@yourdomain.com`
- **Medical certifications**: `medical-cert@yourdomain.com`

You can customize these addresses in the `app/mailboxes/application_mailbox.rb` file.

## Usage

### For Constituents

Constituents can submit proof documents by:

1. Sending an email to `proof@yourdomain.com`
2. Including a clear subject line indicating the type of proof (e.g., "Income Proof" or "Residency Proof")
3. Attaching the proof document(s) in PDF, JPG, or PNG format
4. Including any additional information in the email body

The system will automatically:
- Identify the constituent by their email address
- Determine the proof type from the subject and body
- Attach the document to the constituent's application
- Update the proof status to "pending review"
- Notify administrators of the new submission

### For Medical Providers

Medical providers can submit medical certifications by:

1. Sending an email to `medical-cert@yourdomain.com`
2. Including the application ID in the subject line (e.g., "Medical Certification for Application #123")
3. Attaching the signed certification document in PDF format
4. Including any additional information in the email body

The system will automatically:
- Identify the medical provider by their email address
- Determine the application from the subject line or email body
- Attach the certification to the application
- Update the certification status to "pending review"
- Notify administrators of the new submission

### For Administrators

Administrators can review submitted documents through the admin interface:

1. Navigate to the Applications section
2. Select the application with the new submission
3. Review the attached documents
4. Approve or reject the submission with appropriate notes
5. The system will automatically notify the constituent of the decision

## Testing

You can test the inbound email processing locally using Ultrahook:

1. Install Ultrahook:
   ```bash
   gem install ultrahook
   ```

2. Register for an API key at [ultrahook.com](https://www.ultrahook.com)

3. Add your API key to the configuration file:
   ```bash
   echo "api_key: YOUR_ULTRAHOOK_API_KEY" > ~/.ultrahook
   ```

4. Start Ultrahook to forward webhooks to your local server:
   ```bash
   ultrahook postmark 3000
   ```

5. Configure Postmark to send webhooks to your Ultrahook URL:
   ```
   http://postmark.YOUR_USERNAME.ultrahook.com/rails/action_mailbox/postmark/inbound_emails
   ```

6. Send a test email to your Postmark inbound email address

## Troubleshooting

### Common Issues

1. **Emails not being processed**:
   - Check that the Postmark webhook is correctly configured
   - Verify that "Include raw email content" is enabled in Postmark
   - Check your application logs for any errors

2. **Constituent not found**:
   - Ensure the constituent is using the same email address registered in the system
   - Check if the email address is properly formatted

3. **Proof type not detected**:
   - Make sure the subject line clearly indicates the proof type
   - Check the email body for proof type indicators

4. **Attachments not processed**:
   - Verify that the attachment is in a supported format (PDF, JPG, PNG)
   - Check that the attachment size is within limits (typically under 10MB)
   - Ensure the attachment is not password-protected or corrupted

### Logs and Monitoring

- Action Mailbox logs are stored in the standard Rails logs
- You can monitor inbound email processing in the Action Mailbox dashboard at `/rails/conductor/action_mailbox/inbound_emails`
- Failed inbound emails are marked as "bounced" and can be reviewed in the dashboard

## Security Considerations

- All inbound emails are authenticated using the ingress password
- Attachments are scanned for viruses and malware (if configured)
- File size and type validations are enforced
- Emails from unknown senders are rejected
- All email processing activities are logged for audit purposes
