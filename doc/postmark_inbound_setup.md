# Postmark Inbound Email Setup Guide

This guide provides detailed steps to configure Postmark for receiving inbound emails in your application.

## 1. Create or Access Your Postmark Account

1. Go to [Postmark](https://postmarkapp.com/) and sign in to your account or create a new one.
2. If you don't already have a server set up, create a new server by clicking "Create Server" and following the prompts.

## 2. Set Up Inbound Email Processing

### 2.1 Configure an Inbound Domain

1. In your Postmark dashboard, navigate to your server settings.
2. Click on "Inbound" in the left sidebar.
3. Under "Inbound Settings", click "Edit" next to "Inbound Domain".
4. Enter the domain you want to use for receiving emails (e.g., `inbound.yourdomain.com`).
5. Click "Save Changes".

### 2.2 Set Up DNS Records

1. After setting up your inbound domain, Postmark will provide you with DNS records that need to be added to your domain's DNS configuration.
2. Go to your domain registrar or DNS provider and add the MX records provided by Postmark.
3. Typically, you'll need to add an MX record with priority 10 pointing to `inbound-smtp.postmarkapp.com`.
4. Wait for DNS changes to propagate (this can take up to 24-48 hours, but often happens much faster).

### 2.3 Configure Inbound Webhook

1. In your Postmark dashboard, navigate back to the "Inbound" settings.
2. Under "Webhook URL", enter the URL where Postmark should send incoming emails:
   - For production: `https://actionmailbox:YOUR_INGRESS_PASSWORD@yourdomain.com/rails/action_mailbox/postmark/inbound_emails`
   - For development with Ultrahook: `http://postmark.YOUR_USER.ultrahook.com/rails/action_mailbox/postmark/inbound_emails`
3. Make sure to replace `YOUR_INGRESS_PASSWORD` with the password you set in your Rails credentials.
4. **Important**: Check the box labeled "Include raw email content in JSON payload". This is required for Action Mailbox to work properly.
5. Click "Save Changes".

### 2.4 Set Up Inbound Email Addresses

1. You can set up specific email addresses for different purposes:
   - For proof submissions: `proof@inbound.yourdomain.com`
   - For medical certifications: `medical-cert@inbound.yourdomain.com`
2. These email addresses will be automatically created when emails are sent to them.

### 2.5 Get Your Inbound Hash

1. In your Postmark dashboard, navigate to the "Inbound" settings.
2. Look for the "Inbound Hash" or "Server Hash" value. This is a unique identifier for your server.
3. Copy this hash value as you'll need it for your Rails application configuration.

## 3. Configure Your Rails Application

### 3.1 Add Credentials

1. Open your Rails credentials file:
   ```bash
   bin/rails credentials:edit
   ```

2. Add the following entries:
   ```yaml
   postmark:
     inbound_email_hash: "your_inbound_hash_from_postmark"
     api_token: "your_postmark_api_token"

   action_mailbox:
     ingress_password: "your_strong_random_password"
   ```

3. Save and close the file.

### 3.2 Verify Configuration

1. Make sure the Action Mailbox initializer is properly configured:
   ```ruby
   # config/initializers/action_mailbox.rb
   Rails.application.config.action_mailbox.ingress = :postmark
   ```

2. Ensure your production environment is configured to use Postmark for outgoing emails:
   ```ruby
   # config/application.rb or config/environments/production.rb
   config.action_mailer.delivery_method = :postmark
   config.action_mailer.postmark_settings = {
     api_token: Rails.application.credentials.dig(:postmark, :api_token)
   }
   ```

## 4. Test Your Setup

### 4.1 Local Testing with Ultrahook

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

4. Update your Postmark webhook URL to the Ultrahook URL temporarily.

### 4.2 Send a Test Email

1. Send an email to your configured inbound email address (e.g., `proof@inbound.yourdomain.com`).
2. Attach a test file to the email.
3. Check your Rails logs to see if the email is received and processed.
4. You can also check the Rails conductor at `http://localhost:3000/rails/conductor/action_mailbox/inbound_emails` to see if the email was received.

### 4.3 Verify in Postmark

1. In your Postmark dashboard, navigate to "Inbound".
2. Click on "Messages" to see a list of received inbound emails.
3. You should see your test email in the list.
4. Click on the email to view details, including webhook delivery status.

## 5. Production Deployment

1. Deploy your Rails application with the updated code and configuration.
2. Update the Postmark webhook URL to point to your production URL.
3. Send a test email to verify that everything is working in production.

## Troubleshooting

### Email Not Received

1. Check your domain's MX records to ensure they're correctly pointing to Postmark.
2. Verify that the email address you're sending to matches your inbound domain.
3. Check the Postmark dashboard to see if the email was received by Postmark.

### Webhook Not Triggered

1. Check the Postmark dashboard to see if there were any webhook delivery failures.
2. Verify that your webhook URL is correct and accessible.
3. Ensure that "Include raw email content in JSON payload" is checked.
4. Check your Rails logs for any errors related to Action Mailbox.

### Authentication Issues

1. Verify that the ingress password in your webhook URL matches the one in your Rails credentials.
2. Check that the basic authentication is properly formatted in the URL.

### Processing Issues

1. Check your Rails logs for any errors related to mailbox processing.
2. Verify that your mailbox routing is correctly configured.
3. Ensure that the email sender is recognized as a constituent or medical provider in your system.
