class ProofSubmissionMailbox < ApplicationMailbox
  before_processing :ensure_constituent
  before_processing :ensure_active_application
  before_processing :check_rate_limit
  before_processing :check_max_rejections
  before_processing :validate_attachments

  private

  def ensure_constituent
    unless constituent
      bounce_with_notification(
        :constituent_not_found,
        "Email sender not recognized as a constituent"
      )
    end
  end

  def ensure_active_application
    unless application&.active?
      bounce_with_notification(
        :inactive_application,
        "No active application found for this constituent"
      )
    end
  end

  def check_rate_limit
    RateLimit.check!(:proof_submission, constituent.id, :email)
  rescue RateLimit::ExceededError
    bounce_with_notification(
      :rate_limit_exceeded,
      "You have exceeded the maximum number of proof submissions allowed per hour"
    )
  end

  def check_max_rejections
    if application.total_rejections >= Policy.get("max_proof_rejections")
      bounce_with_notification(
        :max_rejections_reached,
        "Maximum number of proof submission attempts reached"
      )
    end
  end

  def validate_attachments
    if mail.attachments.empty?
      bounce_with_notification(
        :no_attachments,
        "No attachments found in email"
      )
    end

    mail.attachments.each do |attachment|
      begin
        ProofAttachmentValidator.validate!(attachment)
      rescue ProofAttachmentValidator::ValidationError => e
        bounce_with_notification(
          :invalid_attachment,
          "Invalid attachment: #{e.message}"
        )
      end
    end
  end

  def bounce_with_notification(error_type, message)
    Event.create!(
      user: constituent,
      action: "proof_submission_#{error_type}",
      metadata: {
        application_id: application&.id,
        error: message,
        inbound_email_id: inbound_email.id
      }
    )

    bounce_with ApplicationNotificationsMailer.proof_submission_error(
      constituent,
      application,
      error_type,
      message
    )
  end

  def constituent
    @constituent ||= User.find_by(email: mail.from.first)
  end

  def application
    @application ||= constituent&.applications&.last
  end
end
