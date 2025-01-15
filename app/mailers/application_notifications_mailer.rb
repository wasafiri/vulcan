# app/mailers/application_notifications_mailer.rb
class ApplicationNotificationsMailer < ApplicationMailer
  def proof_rejected(application, proof_review)
    @application = application
    @proof_review = proof_review
    @user = application.user

    # Calculate remaining attempts
    @remaining_attempts = 8 - @application.total_rejections
    @reapply_date = 3.years.from_now.to_date.strftime("%B %d, %Y")

    template = EmailTemplate.find_by!(name: "proof_rejection")
    @subject = template.render_subject(
      {
        constituent_name: @user.full_name || "Valued Constituent",
        proof_type: @proof_review.proof_type || "Unknown",
        rejection_reason: @proof_review.rejection_reason || "No reason provided",
        admin_name: @proof_review.admin&.full_name || "Admin",
        application_id: @application.id,
        remaining_attempts: @remaining_attempts
      },
      @proof_review.admin
    )

    mail(to: @user.email, subject: @subject)
  rescue => e
    Event.create!(
      user: @proof_review.admin,
      action: "email_delivery_error",
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: name,
        variables: {
          constituent_name: @user.full_name,
          proof_type: @proof_review.proof_type,
          rejection_reason: @proof_review.rejection_reason,
          admin_name: @proof_review.admin&.full_name,
          application_id: @application.id,
          remaining_attempts: @remaining_attempts
        },
        backtrace: e.backtrace&.first(5)
      }
    )
    raise
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
end
