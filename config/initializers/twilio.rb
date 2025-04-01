# frozen_string_literal: true

# Twilio Configuration
Rails.application.config.twilio = {
  account_sid: ENV.fetch('TWILIO_ACCOUNT_SID', 'OR7f4bf2a319ff163adb313005a34a02a9'),
  auth_token: ENV.fetch('TWILIO_AUTH_TOKEN', nil),
  fax_from_number: ENV.fetch('TWILIO_FAX_FROM_NUMBER', nil)
}
