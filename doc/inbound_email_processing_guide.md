# Inbound Email Processing Guide

This comprehensive guide explains how to set up, configure, and use the inbound email processing feature in the application. This guide consolidates information from previously separate documents and provides up-to-date instructions.

## Overview

The application uses Rails' Action Mailbox to process incoming emails. This allows:

- **Constituents** to submit proof documents (income and residency)
- **Medical providers** to submit medical certifications

When an email is sent to our Postmark inbound address, the system:

1. Receives the email via a webhook from Postmark
2. Routes the email to the appropriate mailbox based on addressing rules
3. Processes the email and its attachments
4. Associates the attachments with the correct application
5. Updates application status as needed
6. Records events for audit purposes

## Current Configuration

The application is currently configured to use Postmark for inbound email processing. The inbound email address is:

```
af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com
```

## Setup Instructions

### 1. Postmark Configuration

1. Log in to your [Postmark account](https://postmarkapp.com)
2. Navigate to your server settings
3. Go to the "Inbound" tab
4. Ensure inbound processing is enabled
5. Configure the webhook URL to point to your application's Action Mailbox endpoint:
   ```
   https://yourdomain.com/rails/action_mailbox/postmark/inbound_emails
   ```
6. **Important**: Check the box labeled "Include raw email content in JSON payload"
7. Set the webhook authentication password to match your `RAILS_INBOUND_EMAIL_PASSWORD`

### 2. Application Configuration

#### Environment Variables

Set these environment variables in your application environment:

```
INBOUND_EMAIL_PROVIDER=postmark
INBOUND_EMAIL_ADDRESS=af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com
RAILS_INBOUND_EMAIL_PASSWORD=your_secure_webhook_password
```

#### Credentials Configuration

Alternatively, configure these settings in your Rails credentials:

```bash
bin/rails credentials:edit
```

Add the following to your credentials file:

```yaml
# Provider-agnostic inbound email configuration
inbound_email:
  provider: postmark
  address: af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com
  
# Provider-specific settings
postmark:
  api_token: your_postmark_api_token

action_mailbox:
  ingress_password: your_secure_password_here
```

## Usage Instructions

### For Constituents

Constituents can submit proof documents by:

1. Sending an email to `af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com`
2. Including a clear subject line indicating the type of proof (e.g., "Income Proof" or "Residency Proof")
3. Attaching the proof document(s) in PDF, JPG, or PNG format
4. Including any additional information in the email body

The system will automatically:
- Identify the constituent by their email address
- Determine the proof type from the subject and body
- Attach the document to the constituent's application
- Update the proof status to "pending review"
- Create events for audit purposes

### For Medical Providers

Medical providers can submit medical certifications by:

1. Sending an email to `af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com`
2. Including the application ID in the subject line (e.g., "Medical Certification for Application #123")
3. Attaching the signed certification document in PDF format
4. Including any additional information in the email body

The system will automatically route these to the `MedicalCertificationMailbox` when the subject or body contains medical certification keywords.

### For Administrators

Administrators can:

1. Review submitted documents through the admin interface
2. Approve or reject submissions with appropriate notes
3. View event logs for inbound email activity
4. Monitor the Action Mailbox dashboard at `/rails/conductor/action_mailbox/inbound_emails`

## Testing

### Running Tests

A test script is available to verify inbound email configuration:

```bash
bin/test-inbound-emails
```

This script runs the unit tests for the inbound email configuration module.

### Manual Testing

For manual testing of the actual inbound email flow:

1. Send a test email to `af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com`
2. Check the Postmark dashboard to confirm receipt
3. Review application logs to verify processing
4. Check the Action Mailbox dashboard at `/rails/conductor/action_mailbox/inbound_emails`
5. Verify proof attachments appear on the relevant application

### Local Testing with Ultrahook

For local development, use Ultrahook to forward webhooks:

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

## Troubleshooting

### Common Issues

1. **Inbound emails not being processed**:
   - Check that the Postmark webhook is correctly configured
   - Verify that "Include raw email content" is enabled in Postmark
   - Ensure the RAILS_INBOUND_EMAIL_PASSWORD matches between your app and Postmark

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

- Monitor inbound email processing in the logs:
  ```bash
  tail -f log/development.log | grep "Inbound"
  ```

- Check the Postmark dashboard for webhook delivery status
- Review the Action Mailbox dashboard at `/rails/conductor/action_mailbox/inbound_emails`

## Application Architecture

### Key Files

- `config/initializers/01_inbound_email_config.rb` - Provider-agnostic configuration module
- `config/initializers/02_action_mailbox.rb` - ActionMailbox setup
- `app/mailboxes/application_mailbox.rb` - Email routing rules
- `app/mailboxes/proof_submission_mailbox.rb` - Proof processing logic
- `app/mailboxes/medical_certification_mailbox.rb` - Medical certification processing

### Email Routing

The `ApplicationMailbox` routes incoming emails based on these rules:

1. Emails sent to our Postmark inbound address (`af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com`) are routed to the `ProofSubmissionMailbox`
2. Emails with subjects containing "medical certification" are routed to the `MedicalCertificationMailbox`
3. All other emails fall back to the default mailbox

### Validation and Security

The system implements several security measures:

- Authentication of webhook requests using the ingress password
- Validation of sender email addresses against registered users
- Rate limiting of submissions to prevent abuse
- Maximum rejection checking to prevent excessive resubmissions
- Attachment validation for file type, size, and content

## Switching Email Providers

If needed, you can switch to a different email provider:

1. Update the environment variables or credentials:
   ```
   INBOUND_EMAIL_PROVIDER=mailgun
   INBOUND_EMAIL_ADDRESS=your_mailgun_address@yourdomain.com
   ```

2. Update the Action Mailbox ingress configuration:
   ```ruby
   # config/initializers/action_mailbox.rb
   Rails.application.config.action_mailbox.ingress = :mailgun
   ```

3. Configure the new provider's webhook URL and authentication
