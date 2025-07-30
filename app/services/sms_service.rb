# frozen_string_literal: true

class SmsService
  def self.send_message(phone_number, message)
    # In production, this would use a real SMS provider like Twilio
    # Here, let's log the message and simulate delivery

    # Example Twilio implementation (commented out):
    # client = Twilio::REST::Client.new(
    #   Rails.application.credentials.twilio[:account_sid],
    #   Rails.application.credentials.twilio[:auth_token]
    # )
    #
    # client.messages.create(
    #   from: Rails.application.credentials.twilio[:phone_number],
    #   to: phone_number,
    #   body: message
    # )

    # For development/testing, log the message
    Rails.logger.info("SMS to #{phone_number}: #{message}")

    # Return true to simulate successful delivery
    true
  rescue StandardError => e
    Rails.logger.error("SMS delivery failed: #{e.message}")
    raise
  end
end
