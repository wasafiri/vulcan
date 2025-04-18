# frozen_string_literal: true

class MedicalProviderMailer < ApplicationMailer
  include Rails.application.routes.url_helpers

  def self.default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  # Notify a medical provider that a certification has been rejected
  # @param application [Application] The application with the rejected certification
  # @param rejection_reason [String] The reason for rejection
  # @param admin [User] The admin who rejected the certification
  def certification_rejected(application, rejection_reason, admin)
    @application = application
    @rejection_reason = rejection_reason
    @admin = admin
    @constituent = application.user
    @remaining_attempts = 8 - application.total_rejections

    mail_options = {
      to: application.medical_provider_email,
      from: 'info@mdmat.org',
      reply_to: 'medical-certification@maryland.gov',
      subject: 'Disability Certification Form for Patient needs Updates',
      message_stream: 'outbound'
    }

    mail(mail_options)
  end

  # Request certification from a medical provider
  # @param application [Application] The application requiring certification
  # @param timestamp [String] ISO8601 timestamp of when the request was made
  # @param notification_id [Integer] ID of the notification record for tracking
  def request_certification(application, timestamp = nil, notification_id = nil)
    @application = application
    @constituent = application.user
    @timestamp = timestamp || Time.current.iso8601
    @notification_id = notification_id
    @request_count = application.medical_certification_request_count || 1

    mail_options = {
      to: application.medical_provider_email,
      from: 'info@mdmat.org',
      reply_to: 'medical-certification@maryland.gov',
      subject: "Disability Certification Form Request for #{application.constituent_full_name}",
      message_stream: 'outbound'
    }

    # Add notification message ID for tracking if available
    if notification_id.present?
      notification = Notification.find_by(id: notification_id)
      mail_options[:message_id] = notification.message_id if notification&.message_id.present?
    end

    mail(mail_options)
  end

  # Notify a medical provider about an error during certification submission
  # @param medical_provider [User] The medical provider who sent the email
  # @param application [Application, nil] The associated application, if found
  # @param error_type [Symbol] The type of error (:provider_not_found, :invalid_certification_request, etc.)
  # @param message [String] The error message
  def certification_submission_error(medical_provider, application, error_type, message)
    @medical_provider = medical_provider
    @application = application
    @constituent = application&.user
    @error_type = error_type
    @message = message

    mail(
      to: @medical_provider.email,
      subject: 'Error Processing Your Certification Submission',
      message_stream: 'outbound' # Use appropriate stream
    )
  end
end
