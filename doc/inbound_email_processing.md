# Inbound Email Processing

This document describes how to set up and use the inbound email processing functionality for receiving proof submissions and medical certifications via email.

## Overview

The application uses Action Mailbox to process incoming emails from constituents and medical professionals. This allows:

1. Constituents to submit income and residency proofs via email
2. Medical professionals to submit medical certifications via email

## Setup

### 1. Configuration

The Action Mailbox is already configured to use Postmark as the ingress. The configuration is in `config/initializers/action_mailbox.rb`.

### 2. Credentials

You need to add the following credentials to your Rails application:

```bash
bin/rails credentials:edit
```

Add the following:

```yaml
postmark:
  inbound_email_hash: "your_inbound_email_hash"  # The hash for your inbound email address

action_mailbox:
  ingress_password: "strong_random_password"  # Password for authenticating webhook requests
```

### 3. Postmark Setup

1. In your Postmark account, go to the Server Settings > Inbound
2. Enable Inbound Email Processing
3. Set the Webhook URL to your production URL:
   `https://actionmailbox:YOUR_INGRESS_PASSWORD@yourdomain.com/rails/action_mailbox/postmark/inbound_emails`
4. Make sure "Include raw email content in JSON payload" is checked

### 4. Email Addresses

Configure the following email addresses in your domain:

- `proof@yourdomain.com` - For proof submissions from constituents
- `medical-cert@yourdomain.com` - For medical certifications from medical professionals

## Local Development and Testing

For local development and testing, you can use Ultrahook to forward webhook requests from Postmark to your local machine:

1. Install Ultrahook:

```bash
gem install ultrahook
```

2. Configure your Ultrahook API key:

```bash
echo "api_key: YOUR_ULTRAHOOK_API_KEY" > ~/.ultrahook
```

3. Start Ultrahook:

```bash
ultrahook postmark 3000
```

4. Update your Postmark webhook URL to the Ultrahook URL:
   `http://postmark.YOUR_USER.ultrahook.com/rails/action_mailbox/postmark/inbound_emails`

5. You can also use the Rails conductor to manually create and process inbound emails:
   http://localhost:3000/rails/conductor/action_mailbox/inbound_emails

## Email Processing Flow

### Proof Submission

1. Constituent sends an email to `proof@yourdomain.com` with proof documents attached
2. The email is routed to the `ProofSubmissionMailbox`
3. The mailbox validates the constituent and application
4. The mailbox determines the proof type (income or residency) based on the email subject and content
5. The mailbox attaches the documents to the appropriate proof type in the application
6. An event is created to record the submission
7. The admin can view the submitted proofs in the application details page

### Medical Certification

1. Medical professional sends an email to `medical-cert@yourdomain.com` with certification document attached
2. The email is routed to the `MedicalCertificationMailbox`
3. The mailbox validates the medical provider and application
4. The mailbox attaches the document to the medical certification in the application
5. An event is created to record the submission
6. The constituent is notified that their certification has been received
7. The admin can view the submitted certification in the application details page

## Testing

The inbound email processing functionality is thoroughly tested with:

1. Unit tests for the mailboxes in `test/mailboxes/`:
   - `test/mailboxes/proof_submission_mailbox_test.rb` - Tests for the proof submission mailbox
   - `test/mailboxes/medical_certification_mailbox_test.rb` - Tests for the medical certification mailbox
   - `test/mailboxes/edge_cases_test.rb` - Tests for edge cases and error handling

2. Integration tests for the end-to-end flow:
   - `test/integration/inbound_email_processing_test.rb` - Tests the full flow from receiving an email to processing it

3. Controller tests for the Postmark webhook endpoint:
   - `test/controllers/rails/action_mailbox/postmark/inbound_emails_controller_test.rb` - Tests the webhook endpoint

4. System tests for the admin interface:
   - `test/system/admin/proof_email_submission_test.rb` - Tests the admin interface for viewing submitted proofs

These tests cover:
- Basic functionality for receiving and processing emails
- Edge cases like emails with no attachments, invalid attachments, or oversized attachments
- Error handling for rate limiting, invalid senders, etc.
- Security aspects like authentication for the webhook endpoint
- End-to-end flow from receiving an email to viewing the attachments in the admin interface

To run the tests:

```bash
bin/rails test:mailboxes     # Run mailbox tests
bin/rails test:integration   # Run integration tests
bin/rails test:controllers   # Run controller tests
bin/rails test:system        # Run system tests
bin/rails test               # Run all tests
```

## Troubleshooting

### Webhook Issues

If webhooks are not being received:

1. Check the Postmark webhook URL is correct
2. Verify the ingress password is set correctly
3. Check the Postmark logs for any errors
4. Check your application logs for any errors

### Email Processing Issues

If emails are not being processed correctly:

1. Check the Action Mailbox inbound emails in the Rails conductor
2. Verify the email addresses are configured correctly
3. Check the application logs for any errors
4. Verify the mailbox routing is correct
