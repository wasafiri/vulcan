# Email System

This document covers the complete email infrastructure in the MAT Vulcan application, including template management, inbound processing, letter generation, and message streams.

## Table of Contents
1. [Email Template Management](#email-template-management)
2. [Inbound Email Processing](#inbound-email-processing)
3. [Letter Generation](#letter-generation)
4. [Postmark Configuration](#postmark-configuration)

---

## Email Template Management

### Overview
Email templates are stored in the database (`email_templates` table) and managed via the admin interface. This provides a single source of truth for both emails and printed letters.

### Template Structure
- **Configuration**: Defined in `EmailTemplate::AVAILABLE_TEMPLATES` constant
- **Storage Format**: Database records with name, format (:html/:text), subject, and body
- **Variable Placeholders**: Uses `%{variable_name}` or `%<variable_name>s` format

### Seeding Templates
Templates are seeded from `db/seeds/email_templates/` directory:

```bash
rails db:seed:email_templates
# or
rake db:seed_manual_email_templates
```

### Mailer Implementation
Mailers retrieve templates from the database:

```ruby
def password_reset
  template_name = 'user_mailer_password_reset'
  html_template = EmailTemplate.find_by!(name: template_name, format: :html)
  text_template = EmailTemplate.find_by!(name: template_name, format: :text)
  
  variables = {
    user_first_name: @user.first_name,
    reset_url: edit_password_url(token: @user.generate_token_for(:password_reset))
  }
  
  rendered_subject, rendered_html_body = html_template.render(**variables)
  _, rendered_text_body = text_template.render(**variables)
  
  mail(to: @user.email, subject: rendered_subject) do |format|
    format.html { render html: rendered_html_body.html_safe }
    format.text { render plain: rendered_text_body }
  end
end
```

### Admin Interface
- **Index View**: Lists all email templates with management actions
- **Show View**: Displays template details and variables
- **Edit View**: Allows editing template subject and body
- **Test Email View**: Preview templates with variables substituted and send test emails

---

## Inbound Email Processing

### Overview
Uses Rails' Action Mailbox with Postmark to process incoming emails for proof submissions and medical certifications.

### Configuration
**Postmark Inbound Address**: `af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com`

**Environment Variables**:
```
INBOUND_EMAIL_PROVIDER=postmark
INBOUND_EMAIL_ADDRESS=af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com
RAILS_INBOUND_EMAIL_PASSWORD=your_secure_webhook_password
```

### Email Routing
The `ApplicationMailbox` routes emails:
1. Emails to the Postmark inbound address → `ProofSubmissionMailbox`
2. Emails with "medical certification" in subject → `MedicalCertificationMailbox`
3. All other emails → default mailbox

### Usage

**For Constituents** (proof submission):
- Send email to inbound address
- Include clear subject line indicating proof type
- Attach documents in PDF, JPG, or PNG format

**For Medical Providers** (certifications):
- Send email to inbound address
- Include application ID in subject line
- Attach signed certification document

### Testing
```bash
# Run inbound email tests
bin/test-inbound-emails

# For local development with Ultrahook
ultrahook postmark 3000
```

---

## Letter Generation

### Overview
The `TextTemplateToPdfService` generates PDF letters from email templates for constituents who prefer physical mail.

### Email-Letter Consistency
When an email is sent to a constituent with `communication_preference == 'letter'`:
1. Email is sent as usual
2. Letter is generated using the text template
3. `PrintQueueItem` is created with attached PDF

### Implementation
```ruby
# In mailers
if user.communication_preference == 'letter'
  Letters::TextTemplateToPdfService.new(
    template_name: 'application_notifications_account_created',
    recipient: user,
    variables: {
      email: user.email,
      temp_password: temp_password,
      first_name: user.first_name,
      last_name: user.last_name
    }
  ).queue_for_printing
end
```

### Print Queue Management
Admins can manage letters through `/admin/print_queue`:
- View pending letters
- Mark letters as printed
- Download PDFs

### Letter Types
Available letter types in `PrintQueueItem.letter_type` enum:
- `account_created`, `income_proof_rejected`, `residency_proof_rejected`
- `income_threshold_exceeded`, `application_approved`, `registration_confirmation`
- `proof_approved`, `max_rejections_reached`, `proof_submission_error`
- `evaluation_submitted`, `other_notification`

---

## Postmark Configuration

### Message Streams
Emails are categorized into streams with different delivery configurations:

1. **`outbound`**: Transactional emails (password resets, system notifications)
2. **`notifications`**: Customer-facing notifications (voucher assignments, status updates)

### Setting Message Streams
```ruby
mail(
  to: recipient.email,
  subject: "Subject line",
  message_stream: "outbound"  # or "notifications"
)
```

### Configuration Files
- `config/initializers/postmark_format.rb`: Basic Postmark configuration
- `config/initializers/postmark_debugger.rb`: Payload transformation and debugging

### Email Tracking
For emails requiring tracking (like medical certifications):

1. **Open Tracking**: Enabled in configuration with `track_opens: true`
2. **API Token**: Set `POSTMARK_API_TOKEN` environment variable
3. **Message ID Capture**: Mailers record Postmark message IDs for tracking
4. **Status Updates**: Use `UpdateEmailStatusJob` to check delivery status

### Debugging
Check logs for:
- `POSTMARK PAYLOAD (ORIGINAL)`: Original payload before transformation
- `POSTMARK PAYLOAD (MODIFIED)`: Modified payload after transformations
- `POSTMARK SUCCESS/ERROR`: Delivery status

---

## Testing Email System

### Template Testing
Most tests use mock templates to avoid database dependencies:

```ruby
def mock_template(subject_format, body_format)
  template = mock('email_template')
  template.stubs(:render).with(any_parameters).returns do |**vars|
    rendered_subject = subject_format % vars
    rendered_body = body_format % vars
    [rendered_subject, rendered_body]
  end
  template
end
```

### Inbound Email Testing
- Use the test script: `bin/test-inbound-emails`
- Check Action Mailbox dashboard: `/rails/conductor/action_mailbox/inbound_emails`
- For local testing, use Ultrahook to forward webhooks

### Letter Generation Testing
- Test `TextTemplateToPdfService` in `test/services/letters/`
- Verify `PrintQueueItem` creation
- Test template variable substitution

---

## Troubleshooting

### Common Issues
1. **Template Not Found**: Verify template exists in database and name matches exactly
2. **Inbound Emails Not Processing**: Check Postmark webhook configuration and password
3. **Letter Generation Failing**: Ensure text templates exist and variables are properly defined
4. **Message Stream Issues**: Verify stream names and Postmark configuration

### Debugging Tools
- Admin email template interface for testing templates
- Action Mailbox dashboard for inbound email inspection
- Print queue interface for letter management
- Postmark dashboard for delivery status and webhook logs 