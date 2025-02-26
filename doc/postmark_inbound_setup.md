# Postmark Inbound Email Setup Guide

This guide provides detailed instructions for setting up Postmark to handle inbound emails for the application. It complements the general [Inbound Email Processing](./inbound_email_processing.md) documentation.

## Prerequisites

- A Postmark account ([Sign up here](https://postmarkapp.com/sign-up) if you don't have one)
- A verified domain in Postmark
- Admin access to your DNS settings

## Step 1: Create a Server in Postmark

1. Log in to your Postmark account
2. Click "Servers" in the top navigation
3. Click "New Server"
4. Enter a name for your server (e.g., "MAT Vulcan Inbound")
5. Click "Create Server"

## Step 2: Set Up an Inbound Domain

1. In your server dashboard, click "Settings" in the left sidebar
2. Click "Inbound" in the settings menu
3. Under "Inbound Domain," click "Add Domain"
4. Enter your inbound domain (e.g., `inbound.yourdomain.com`)
5. Click "Add Domain"

## Step 3: Configure DNS Records

Postmark will provide you with the necessary DNS records to set up your inbound domain. You'll need to add these records to your domain's DNS settings:

1. Add an MX record:
   - Host: `inbound` (or whatever subdomain you chose)
   - Value: `inbound-smtp.postmarkapp.com`
   - Priority: `10`

2. Add a TXT record (optional, but recommended for SPF):
   - Host: `inbound` (or whatever subdomain you chose)
   - Value: `v=spf1 include:spf.mtasv.net ~all`

3. Wait for DNS propagation (this can take up to 24-48 hours)

## Step 4: Configure Inbound Webhook

1. In your server dashboard, click "Settings" in the left sidebar
2. Click "Inbound" in the settings menu
3. Under "Webhook URL," enter your application's Action Mailbox endpoint:
   ```
   https://yourdomain.com/rails/action_mailbox/postmark/inbound_emails
   ```
4. **Important**: Check the box labeled "Include raw email content in JSON payload"
5. Click "Save Changes"

## Step 5: Configure Inbound Hash

The inbound hash is used to route emails to the correct server in Postmark. You need to configure this in your Rails application:

1. Open the `config/initializers/action_mailbox.rb` file
2. Add the following line:
   ```ruby
   Rails.application.config.postmark_inbound_email_hash = 'your_inbound_hash'
   ```
   Replace `your_inbound_hash` with the hash from your inbound email address (everything before the @ symbol).

## Step 6: Set Up Authentication

1. Generate a secure password for Action Mailbox:
   ```bash
   bin/rails secret | head -c 32
   ```

2. Add the password to your Rails credentials:
   ```bash
   bin/rails credentials:edit
   ```

3. Add the following to your credentials file:
   ```yaml
   action_mailbox:
     ingress_password: your_generated_password
     postmark_api_key: your_postmark_api_key
   ```

4. Save and close the credentials file

## Step 7: Configure Email Addresses

You'll need to set up email addresses for your inbound domain. These are the addresses that constituents and medical providers will send emails to:

1. For proof submissions: `proof@inbound.yourdomain.com`
2. For medical certifications: `medical-cert@inbound.yourdomain.com`

You can create these as wildcard addresses in Postmark, as all emails to your inbound domain will be processed by the webhook.

## Step 8: Test the Setup

### Using Ultrahook for Local Testing

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

5. Update the webhook URL in Postmark to your Ultrahook URL:
   ```
   http://postmark.YOUR_USERNAME.ultrahook.com/rails/action_mailbox/postmark/inbound_emails
   ```

### Send a Test Email

1. Send an email to one of your configured addresses (e.g., `proof@inbound.yourdomain.com`)
2. Include a subject line (e.g., "Income Proof Submission")
3. Attach a PDF file
4. Check your application logs to see if the email was processed
5. Check the Action Mailbox dashboard at `/rails/conductor/action_mailbox/inbound_emails`

## Step 9: Production Configuration

When deploying to production, make sure to:

1. Update the webhook URL in Postmark to your production URL
2. Ensure your production environment has the correct credentials
3. Set up proper monitoring for inbound email processing

## Troubleshooting

### Common Postmark-Specific Issues

1. **Webhook not receiving emails**:
   - Check that your DNS records are correctly configured
   - Verify that your inbound domain is properly set up in Postmark
   - Make sure the "Include raw email content" option is checked

2. **Authentication failures**:
   - Verify that the ingress password in your Rails credentials matches the one used in the webhook URL
   - Check that your Postmark API key is correctly set in your Rails credentials

3. **Email routing issues**:
   - Confirm that the inbound hash in your Rails configuration matches the one in your Postmark inbound domain
   - Verify that your application_mailbox.rb file has the correct routing rules

### Postmark Logs

Postmark provides detailed logs for inbound email processing:

1. In your server dashboard, click "Activity" in the left sidebar
2. Click "Inbound" to view inbound email logs
3. Click on an individual email to see details about its processing

These logs can be invaluable for troubleshooting issues with inbound email processing.

## Additional Resources

- [Postmark Inbound Documentation](https://postmarkapp.com/developer/user-guide/inbound)
- [Rails Action Mailbox Documentation](https://guides.rubyonrails.org/action_mailbox_basics.html)
- [Ultrahook Documentation](https://www.ultrahook.com/faq)
