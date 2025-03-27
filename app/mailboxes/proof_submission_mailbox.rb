# frozen_string_literal: true

class ProofSubmissionMailbox < ApplicationMailbox
  before_processing :ensure_constituent
  before_processing :ensure_active_application
  before_processing :check_rate_limit
  before_processing :check_max_rejections
  before_processing :validate_attachments

  def process
    # Create an audit record for the submission
    create_audit_record

    # Process each attachment
    mail.attachments.each do |attachment|
      # Determine proof type based on email subject or content
      proof_type = determine_proof_type(mail.subject, mail.body.decoded)

      # Attach the file to the application's proof
      attach_proof(attachment, proof_type)
    end

    # Notify admin of new proof submission
    notify_admin
  end

  private

  def create_audit_record
    Event.create!(
      user: constituent,
      action: 'proof_submission_received',
      metadata: {
        application_id: application.id,
        inbound_email_id: inbound_email.id,
        email_subject: mail.subject,
        email_from: mail.from.first
      }
    )
  end

  def determine_proof_type(subject, body)
    subject = subject.downcase
    body = body.downcase

    if subject.include?('income') || body.include?('income')
      :income
    elsif subject.include?('residency') || body.include?('residency') ||
          subject.include?('address') || body.include?('address')
      :residency
    else
      # Default to income if we can't determine
      :income
    end
  end

  def attach_proof(attachment, proof_type)
    # Create a blob from the attachment
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(attachment.body.decoded),
      filename: attachment.filename,
      content_type: attachment.content_type
    )

    # Use the ProofAttachmentService to consistently handle attachments
    result = ProofAttachmentService.attach_proof(
      application: application,
      proof_type: proof_type,
      blob_or_file: blob,
      status: :not_reviewed,
      admin: nil,
      submission_method: :email,
      metadata: {
        ip_address: '0.0.0.0',
        email_subject: mail.subject,
        email_from: mail.from.first,
        inbound_email_id: inbound_email.id
      }
    )

    return if result[:success]

    Rails.logger.error "Failed to attach proof via email: #{result[:error]&.message}"
    raise "Failed to attach proof: #{result[:error]&.message}"
  end

  def notify_admin
    # Notify admin of new proof submission
    Event.create!(
      user: constituent,
      action: 'proof_submission_processed',
      metadata: {
        application_id: application.id,
        inbound_email_id: inbound_email.id
      }
    )
  end

  def ensure_constituent
    return if constituent

    bounce_with_notification(
      :constituent_not_found,
      'Email sender not recognized as a constituent'
    )
  end

  def ensure_active_application
    return if application&.active?

    bounce_with_notification(
      :inactive_application,
      'No active application found for this constituent'
    )
  end

  def check_rate_limit
    RateLimit.check!(:proof_submission, constituent.id, :email)
  rescue RateLimit::ExceededError
    bounce_with_notification(
      :rate_limit_exceeded,
      'You have exceeded the maximum number of proof submissions allowed per hour'
    )
  end

  def check_max_rejections
    return unless application.total_rejections >= Policy.get('max_proof_rejections')

    bounce_with_notification(
      :max_rejections_reached,
      'Maximum number of proof submission attempts reached'
    )
  end

  def validate_attachments
    if mail.attachments.empty?
      bounce_with_notification(
        :no_attachments,
        'No attachments found in email'
      )
    end

    mail.attachments.each do |attachment|
      ProofAttachmentValidator.validate!(attachment)
    rescue ProofAttachmentValidator::ValidationError => e
      bounce_with_notification(
        :invalid_attachment,
        "Invalid attachment: #{e.message}"
      )
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
