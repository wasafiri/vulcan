# frozen_string_literal: true

# Centralized configuration for all inbound email processing
module MatVulcan
  module InboundEmailConfig
    # Store provider information
    mattr_accessor :provider
    @@provider = (ENV['INBOUND_EMAIL_PROVIDER'] ||
                 Rails.application.credentials.dig(:inbound_email, :provider) ||
                 :postmark).to_sym # Default provider

    # Store all inbound email configuration in one place
    mattr_accessor :inbound_email_address
    @@inbound_email_address = ENV['INBOUND_EMAIL_ADDRESS'] ||
                              Rails.application.credentials.dig(:inbound_email, :address) ||
                              'af7eff0e94107d69e60ac99b335358b1@inbound.postmarkapp.com'

    # Extract the hash part (everything before @) for routing
    def self.inbound_email_hash
      inbound_email_address.split('@').first
    end

    # Extract the domain part for domain-based routing
    def self.inbound_email_domain
      inbound_email_address.split('@').last
    end

    # Helper method to determine if we're using a specific provider
    def self.using?(provider_name)
      provider.to_sym == provider_name.to_sym
    end

    # Provider-specific configuration
    def self.provider_config
      case provider
      when :postmark
        {
          ingress: :postmark,
          config_key: :postmark_inbound_email_hash,
          config_value: inbound_email_hash
        }
      when :mailgun
        {
          ingress: :mailgun,
          config_key: :mailgun_routing_key, # Example for Mailgun
          config_value: ENV['MAILGUN_API_KEY'] || Rails.application.credentials.dig(:mailgun, :api_key)
        }
      when :sendgrid
        {
          ingress: :sendgrid,
          config_key: :sendgrid_ingress_key, # Example for SendGrid
          config_value: ENV['SENDGRID_WEBHOOK_KEY'] || Rails.application.credentials.dig(:sendgrid, :webhook_key)
        }
      else
        {
          ingress: :relay, # Default to standard SMTP relay
          config_key: nil,
          config_value: nil
        }
      end
    end
  end
end
