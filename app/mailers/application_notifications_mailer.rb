class ApplicationNotificationsMailer < ApplicationMailer
  include Rails.application.routes.url_helpers
  include Mailers::ApplicationNotificationsHelper

  def self.default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  def proof_approved(application, proof_review)
    @application = application
    @proof_review = proof_review
    @user = application.user

    mail(
      to: @user.email,
      subject: "Document Review Update: Your #{format_proof_type(@proof_review.proof_type)} documentation has been approved",
      template_path: "application_notifications_mailer",
      template_name: "proof_approved"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send proof approval email: #{e.message}")
  end

  def proof_rejected(application, proof_review)
    @application = application
    @proof_review = proof_review
    @user = application.user

    # Calculate remaining attempts
    @remaining_attempts = 8 - @application.total_rejections
    @reapply_date = 3.years.from_now.to_date.strftime("%B %d, %Y")

    mail(
      to: @user.email,
      subject: "Document Review Update: Your #{format_proof_type(@proof_review.proof_type)} documentation needs revision",
      template_path: "application_notifications_mailer",
      template_name: "proof_rejected"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send proof rejection email: #{e.message}")
  end

  def max_rejections_reached(application)
    @application = application
    @user = application.user

    mail(
      to: @user.email,
      subject: "Important: Application Status Update",
      template_path: "application_notifications_mailer",
      template_name: "max_rejections_reached"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send max rejections email: #{e.message}")
  end

  def proof_needs_review_reminder(admin, applications)
    @admin = admin
    @applications = applications
    @stale_reviews = applications.select { |app| app.needs_review_since < 3.days.ago }

    return if @stale_reviews.empty?

    mail(
      to: @admin.email,
      subject: "Reminder: Applications Awaiting Proof Review",
      template_path: "application_notifications_mailer",
      template_name: "proof_needs_review_reminder"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send review reminder email: #{e.message}")
  end

  helper Mailers::ApplicationNotificationsHelper

  private
end
