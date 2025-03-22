class MedicalCertificationMailbox < ApplicationMailbox
  before_processing :ensure_medical_provider
  before_processing :ensure_valid_certification_request
  before_processing :validate_attachments

  def process
    # Create an audit record for the submission
    audit = create_audit_record

    # Process each attachment
    mail.attachments.each do |attachment|
      # Attach the certification to the application
      attach_certification(attachment, audit)
    end

    # Notify admin of new certification submission
    notify_admin

    # Notify constituent that their certification has been received
    notify_constituent
  end

  private

  def create_audit_record
    Event.create!(
      user: application.constituent,
      action: 'medical_certification_received',
      metadata: {
        application_id: application.id,
        medical_provider_id: medical_provider.id,
        inbound_email_id: inbound_email.id,
        email_subject: mail.subject,
        email_from: mail.from.first
      }
    )
  end

  def attach_certification(attachment, _audit)
    # Create a blob from the attachment
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(attachment.body.decoded),
      filename: attachment.filename,
      content_type: attachment.content_type
    )

    # Attach the blob to the application's medical certification
    application.medical_certification.attach(blob)
  end

  def notify_admin
    # Notify admin of new certification submission
    Event.create!(
      user: application.constituent,
      action: 'medical_certification_received',
      metadata: {
        application_id: application.id,
        medical_provider_id: medical_provider.id,
        inbound_email_id: inbound_email.id
      }
    )
  end

  def notify_constituent
    # Notify constituent that their certification has been received
    ApplicationNotificationsMailer.medical_certification_received(
      application.constituent,
      application
    ).deliver_later if defined?(ApplicationNotificationsMailer.medical_certification_received)
  end

  def ensure_medical_provider
    unless medical_provider
      bounce_with_notification(
        :provider_not_found,
        'Email sender not recognized as a registered medical provider'
      )
    end
  end

  def ensure_valid_certification_request
    unless application && application.medical_certification_requested?
      bounce_with_notification(
        :invalid_certification_request,
        'No pending certification request found for this provider'
      )
    end
  end

  def validate_attachments
    if mail.attachments.empty?
      bounce_with_notification(
        :no_attachments,
        'No attachments found in email'
      )
    end

    mail.attachments.each do |attachment|
      begin
        validate_attachment(attachment)
      rescue StandardError => e
        bounce_with_notification(
          :invalid_attachment,
          "Invalid attachment: #{e.message}"
        )
      end
    end
  end

  def validate_attachment(attachment)
    # Check file size
    if attachment.body.decoded.size > 10.megabytes
      raise 'File size exceeds 10MB limit'
    end

    # Check file type
    allowed_types = %w[application/pdf image/jpeg image/png image/gif]
    unless allowed_types.include?(attachment.content_type)
      raise 'File type not allowed. Allowed types: PDF, JPEG, PNG, GIF'
    end
  end

  def bounce_with_notification(error_type, message)
    Event.create!(
      user: application&.constituent,
      action: "medical_certification_#{error_type}",
      metadata: {
        application_id: application&.id,
        medical_provider_id: medical_provider&.id,
        error: message,
        inbound_email_id: inbound_email.id
      }
    )

    if defined?(MedicalProviderMailer.certification_submission_error)
      bounce_with MedicalProviderMailer.certification_submission_error(
        medical_provider,
        application,
        error_type,
        message
      )
    else
      # If the mailer method doesn't exist, just bounce with a simple message
      bounce_with message
    end
  end

  def medical_provider
    @medical_provider ||= MedicalProvider.find_by(email: mail.from.first)
  end

  def application
    # Extract application ID from the email subject or body
    # This assumes you include an application ID in the original request email
    application_id = extract_application_id_from_email
    @application ||= Application.find_by(id: application_id)
  end

  def extract_application_id_from_email
    # Look for application ID in subject (e.g., "Medical Certification for Application #123")
    subject_match = mail.subject.match(/Application #?(\d+)/i)
    return subject_match[1] if subject_match

    # Look for application ID in email body
    body_match = mail.body.decoded.match(/Application #?(\d+)/i)
    return body_match[1] if body_match

    # If we can't find an ID, check if this is a reply to a specific request
    # This assumes you're using a mailbox hash with the application ID
    if mail.to.any? { |to| to.include?("+") }
      mailbox_hash = mail.to.find { |to| to.include?('+') }.split('@').first.split('+').last
      return mailbox_hash if mailbox_hash.match?(/^\d+$/)
    end

    nil
  end
end
