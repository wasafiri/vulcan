# Configure Action Mailbox
provider_config = MatVulcan::InboundEmailConfig.provider_config

# Configure ingress based on the selected provider
Rails.application.config.action_mailbox.ingress = provider_config[:ingress]

# Apply provider-specific configuration if needed
if provider_config[:config_key].present? && provider_config[:config_value].present?
  Rails.application.config.action_mailbox.send("#{provider_config[:config_key]}=", provider_config[:config_value])
end

# Configure Action Mailbox to use Postmark for inbound emails
Rails.application.config.to_prepare do
  # Set the ingress password for Postmark
  if Rails.application.credentials.dig(:action_mailbox, :ingress_password).present?
    # In Rails 8.0.1, the configuration method has changed
    Rails.application.config.action_mailbox.ingress_password =
      Rails.application.credentials.dig(:action_mailbox, :ingress_password)
  end
end
