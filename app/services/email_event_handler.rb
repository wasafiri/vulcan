# frozen_string_literal: true

class EmailEventHandler
  def initialize(params)
    @params = params
    @event_type = params[:event]
  end

  def process
    case @event_type
    when 'bounce'
      handle_bounce
    when 'complaint'
      handle_complaint
    else
      Rails.logger.warn("Unhandled email event type: #{@event_type}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("Error processing email event: #{e.message}")
    Honeybadger.notify(e) if defined?(Honeybadger)
    false
  end

  private

  def handle_bounce
    provider_email = find_provider_email
    return false unless provider_email

    bounce_data = @params[:bounce] || {}

    provider_email.mark_as_bounced!(
      bounce_type: bounce_data[:type],
      diagnostics: bounce_data[:diagnostics]
    )

    # Create an audit event
    Event.create!(
      action: 'email_bounced',
      metadata: {
        provider_email_id: provider_email.id,
        bounce_type: bounce_data[:type]
      }
    )

    true
  end

  def handle_complaint
    provider_email = find_provider_email
    return false unless provider_email

    provider_email.update!(
      status: :complained,
      complained_at: Time.current
    )
    true
  end

  def find_provider_email
    MedicalProviderEmail.find_by(email: @params[:email])
  end
end
