# frozen_string_literal: true

WebAuthn.configure do |config|
  # Relying Party name
  config.rp_name = 'MAT Vulcan'

  # Allowed origins (URLs where the app is accessed)
  # Ensure development origin is included
  allowed_origins = []
  allowed_origins << ENV['WEBAUTHN_ORIGIN'] if ENV['WEBAUTHN_ORIGIN'].present?
  allowed_origins << 'http://localhost:3000' if Rails.env.development?

  # Remove duplicates and assign
  config.allowed_origins = allowed_origins.compact.uniq

  # Relying Party ID - explicitly set for localhost development
  if Rails.env.development?
    config.rp_id = 'localhost'
  elsif ENV['WEBAUTHN_RP_ID'].present?
    config.rp_id = ENV['WEBAUTHN_RP_ID']
  end

  # Optional: Configure timeout for credential creation/authentication
  config.credential_options_timeout = 120_000 # Milliseconds
end
