class ApplicationStatus
  def initialize(application)
    @application = application
  end

  def send_back!(actor: nil)
    @application.update(status: :needs_information)
    Notification.create!(
      recipient: @application.user,
      actor: actor,
      action: "application_sent_back",
      metadata: { reason: "Additional information required." },
      notifiable: @application
    )
  end

  def verify_income!(actor: nil)
    @application.update(
      income_verification_status: :verified,
      income_verified_at: Time.current,
      income_verified_by: actor
    )
    Notification.create!(
      recipient: @application.user,
      actor: actor,
      action: "income_verified",
      metadata: {},
      notifiable: @application
    )
  end
end
