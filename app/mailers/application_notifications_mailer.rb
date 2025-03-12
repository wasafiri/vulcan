class ApplicationNotificationsMailer < ApplicationMailer
  use_message_stream :notifications
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
    Rails.logger.info "Preparing #{template_name} email for Application ID: #{application.id}"
    if proof_review
      Rails.logger.info "ProofReview ID: #{proof_review.id}"
      Rails.logger.info "Raw proof_type: #{proof_review.attributes['proof_type']}"
      Rails.logger.info "Enum proof_type: #{proof_review.proof_type}"
      Rails.logger.info "Enum proof_type_before_type_cast: #{proof_review.proof_type_before_type_cast}"
    end
    Rails.logger.info "Delivery method: #{ActionMailer::Base.delivery_method}"

    @application  = application
    @proof_review = proof_review
    @user         = application.user

    extra_setup.call if extra_setup

    formatted_type = proof_review ? format_proof_type(proof_review.proof_type) : "document"
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
        @reapply_date = 3.years.from_now.to_date
      }
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send proof rejection email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  def max_rejections_reached(application)
    Rails.logger.info "Preparing max_rejections_reached email for Application ID: #{application.id}"
    Rails.logger.info "Delivery method: #{ActionMailer::Base.delivery_method}"

    @application = application
    @user = application.user
    @reapply_date = 3.years.from_now.to_date

    mail_obj = mail(
      to: @user.email,
      subject: "Important: Application Status Update",
      template_path: "application_notifications_mailer",
      template_name: "max_rejections_reached"
    )

    Rails.logger.info "Email body: #{mail_obj.body}"
    mail_obj
  rescue StandardError => e
    Rails.logger.error("Failed to send max rejections email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e if Rails.env.test? # Re-raise in test environment
  end

  def proof_needs_review_reminder(admin, applications)
    @admin = admin
    @applications = applications
    @host_url = Rails.application.config.action_mailer.default_url_options[:host]
    @stale_reviews = applications.select do |app|
      app.respond_to?(:needs_review_since) &&
      app.needs_review_since.present? &&
      app.needs_review_since < 3.days.ago
    end

    # Only skip sending in production if there are no stale reviews
    # In test environment, we'll always send the email
    if @stale_reviews.empty? && !Rails.env.test?
      Rails.logger.info("No stale reviews found, skipping reminder email")
      return nil
    end

    mail_obj = mail(
      to: @admin.email,
      subject: "Reminder: Applications Awaiting Proof Review",
      template_path: "application_notifications_mailer",
      template_name: "proof_needs_review_reminder"
    )

    Rails.logger.info "Email body: #{mail_obj.body}"
    mail_obj
  rescue StandardError => e
    Rails.logger.error("Failed to send review reminder email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e if Rails.env.test? # Re-raise in test environment
  end

  helper Mailers::ApplicationNotificationsHelper

  def account_created(constituent, temp_password)
    @constituent = constituent
    @temp_password = temp_password
    @login_url = sign_in_url

    mail(
      to: @constituent.email,
      subject: "Your MAT Application Account Has Been Created"
    )
  end

  def income_threshold_exceeded(constituent_params, notification_params)
    @constituent = OpenStruct.new(constituent_params)
    @notification = OpenStruct.new(notification_params)

    # Calculate the threshold for display in the email
    household_size = @notification.household_size.to_i
    base_fpl = Policy.get("fpl_#{[ household_size, 8 ].min}_person").to_i
    modifier = Policy.get("fpl_modifier_percentage").to_i
    @threshold = base_fpl * (modifier / 100.0)

    mail(
      to: @constituent.email,
      subject: "Important Information About Your MAT Application"
    )
  end

  def proof_submission_error(constituent, application, error_type, message)
    @constituent = constituent
    @application = application
    @error_type = error_type
    @message = message

    mail(
      to: @constituent.email,
      subject: "Error Processing Your Proof Submission"
    )
  end
end
