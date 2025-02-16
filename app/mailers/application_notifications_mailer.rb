class ApplicationNotificationsMailer < ApplicationMailer
  include Rails.application.routes.url_helpers
  include Mailers::ApplicationNotificationsHelper

  def self.default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  # A helper method that handles common logging, instance variable setup,
  # subject formatting, and mail object creation.

  # extra_setup: an optional lambda to run any extra setup (e.g. setting
  #   @remaining_attempts and @reapply_date) before sending the email.

  # subject_template: a string that contains "%{formatted_type}" for interpolation.
  # template_name: the template name to use.
  def prepare_email(application, proof_review, subject_template:, template_name:, extra_setup: nil)
    Rails.logger.info "Preparing #{template_name} email for Application ID: #{application.id}, ProofReview ID: #{proof_review.id}"
    Rails.logger.info "Raw proof_type: #{proof_review.attributes['proof_type']}"
    Rails.logger.info "Enum proof_type: #{proof_review.proof_type}"
    Rails.logger.info "Enum proof_type_before_type_cast: #{proof_review.proof_type_before_type_cast}"
    Rails.logger.info "Delivery method: #{ActionMailer::Base.delivery_method}"

    @application  = application
    @proof_review = proof_review
    @user         = application.user

    extra_setup.call if extra_setup

    formatted_type = format_proof_type(@proof_review.proof_type)
    Rails.logger.info "Formatted proof type: #{formatted_type}"

    subject_line = subject_template % { formatted_type: formatted_type }
    mail_obj = mail(
      to: @user.email,
      subject: subject_line,
      template_path: "application_notifications_mailer",
      template_name: template_name
    )

    Rails.logger.info "Email body: #{mail_obj.body}"
    mail_obj
  end

  def proof_approved(application, proof_review)
    prepare_email(
      application,
      proof_review,
      subject_template: "Document Review Update: Your %{formatted_type} documentation has been approved",
      template_name: "proof_approved"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send proof approval email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  def proof_rejected(application, proof_review)
    prepare_email(
      application,
      proof_review,
      subject_template: "Document Review Update: Your %{formatted_type} documentation needs revision",
      template_name: "proof_rejected",
      extra_setup: -> {
        @remaining_attempts = 8 - @application.total_rejections
        @reapply_date = 3.years.from_now.to_date.strftime("%B %d, %Y")
      }
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send proof rejection email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
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
end
