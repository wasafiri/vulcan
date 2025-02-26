# Configure Action Mailbox
Rails.application.config.action_mailbox.ingress = :postmark

# Set the inbound email hash for Postmark (if available)
if Rails.application.credentials.dig(:postmark, :inbound_email_hash).present?
  Rails.application.config.action_mailbox.postmark_inbound_email_hash =
    Rails.application.credentials.dig(:postmark, :inbound_email_hash)
end

# Configure Action Mailbox to use Postmark for inbound emails
Rails.application.config.to_prepare do
  # Set the ingress password for Postmark
  if Rails.application.credentials.dig(:action_mailbox, :ingress_password).present?
    ActionMailbox::Base.ingress_password =
      Rails.application.credentials.dig(:action_mailbox, :ingress_password)
  end
end
