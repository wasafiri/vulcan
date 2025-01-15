# app/services/email_event_handler.rb
class EmailEventHandler
  def initialize(params)
    @params = params
    @event = params[:event]
  end

  def process
    case @event[:type]
    when "bounce"
      handle_bounce
    when "complaint"
      handle_complaint
    else
      Rails.logger.warn("Unhandled email event type: #{@event[:type]}")
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

    provider_email.mark_as_bounced!(
      bounce_type: @event[:bounce_type],
      diagnostics: @event[:diagnostics]
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
    MedicalProviderEmail.find_by(email: @event[:email])
  end
end
