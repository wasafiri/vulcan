# frozen_string_literal: true

class ApplicationStatus
  def initialize(application)
    @application = application
  end

  def send_back!(actor: nil)
    @application.update(status: :needs_information)
    Notification.create!(
      recipient: @application.user,
      actor: actor,
      action: 'application_sent_back',
      metadata: { reason: 'Additional information required.' },
      notifiable: @application
    )
  end
end
