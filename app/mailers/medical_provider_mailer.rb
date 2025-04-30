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
  def certification_rejected(application, rejection_reason, _admin)
    template_name = 'medical_provider_certification_rejected'
    begin
      html_template = EmailTemplate.find_by!(name: template_name, format: :html)
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email templates not found for #{template_name}"
    end

    # Prepare variables
    constituent = application.user
    remaining_attempts = 8 - application.total_rejections

    variables = {
      constituent_full_name: constituent.full_name,
      application_id: application.id,
      rejection_reason: rejection_reason,
      remaining_attempts: remaining_attempts
      # No optional variables for this template
    }.compact

    # Render subject and bodies
    rendered_subject, rendered_html_body = html_template.render(**variables)
    _, rendered_text_body = text_template.render(**variables)

    # Send email
    mail(
      to: application.medical_provider_email,
      from: 'info@mdmat.org', # Keep existing from/reply_to if specific
      reply_to: 'medical-certification@maryland.gov',
      subject: rendered_subject,
      message_stream: 'outbound'
    ) do |format|
      format.html { render html: rendered_html_body.presence || '' }
      format.text { render plain: rendered_text_body.to_s }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send certification rejected email for application #{application&.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  # Request certification from a medical provider
  # @param application [Application] The application requiring certification
  # @param timestamp [String] ISO8601 timestamp of when the request was made
  # @param notification_id [Integer] ID of the notification record for tracking
  def request_certification(application, timestamp = nil, notification_id = nil)
    template_name = 'medical_provider_request_certification'
    begin
      html_template = EmailTemplate.find_by!(name: template_name, format: :html)
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email templates not found for #{template_name}"
    end

    # Prepare variables
    constituent = application.user
    timestamp_formatted = (timestamp ? Time.iso8601(timestamp) : Time.current).strftime('%B %d, %Y at %I:%M %p %Z')
    request_count = application.medical_certification_request_count || 1
    request_count_message = request_count > 1 ? "This is a follow-up request (Request ##{request_count})" : ''
    constituent_dob_formatted = constituent.date_of_birth&.strftime('%m/%d/%Y') || 'Not Provided'
    # Basic address formatting, could be enhanced
    constituent_address_formatted = [
      constituent.physical_address_1, # Corrected attribute name
      constituent.physical_address_2, # Corrected attribute name
      "#{constituent.city}, #{constituent.state} #{constituent.zip_code}"
    ].compact_blank.join("\n")
    # Generate the download URL (assuming a route helper exists)
    download_form_url = begin
      medical_certification_form_url(application.signed_id(purpose: :medical_certification),
                                     host: default_url_options[:host])
    rescue StandardError
      '#'
    end

    variables = {
      constituent_full_name: constituent.full_name,
      request_count_message: request_count_message,
      timestamp_formatted: timestamp_formatted,
      constituent_dob_formatted: constituent_dob_formatted,
      constituent_address_formatted: constituent_address_formatted,
      application_id: application.id,
      download_form_url: download_form_url
      # No optional variables for this template
    }.compact

    # Render subject and bodies
    rendered_subject, rendered_html_body = html_template.render(**variables)
    _, rendered_text_body = text_template.render(**variables)

    mail_options = {
      to: application.medical_provider_email,
      from: 'info@mdmat.org',
      reply_to: 'medical-certification@maryland.gov',
      subject: rendered_subject,
      message_stream: 'outbound'
    }

    # Add notification message ID for tracking if available
    if notification_id.present?
      notification = Notification.find_by(id: notification_id)
      mail_options[:message_id] = notification.message_id if notification&.message_id.present?
    end

    # Send email
    mail(mail_options) do |format|
      format.html { render html: rendered_html_body.presence || '' }
      format.text { render plain: rendered_text_body.to_s }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send request certification email for application #{application&.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  # Notify a medical provider about an error during certification submission
  # @param medical_provider [User] The medical provider who sent the email
  # @param application [Application, nil] The associated application, if found
  # @param error_type [Symbol] The type of error (:provider_not_found, :invalid_certification_request, etc.)
  # @param message [String] The error message
  def certification_submission_error(medical_provider, application, _error_type, message)
    template_name = 'medical_provider_certification_submission_error'
    begin
      html_template = EmailTemplate.find_by!(name: template_name, format: :html)
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email templates not found for #{template_name}"
    end

    # Prepare variables
    variables = {
      medical_provider_email: medical_provider.email,
      error_message: message,
      # Optional variables
      constituent_full_name: application&.user&.full_name,
      application_id: application&.id
    }.compact

    # Render subject and bodies
    rendered_subject, rendered_html_body = html_template.render(**variables)
    _, rendered_text_body = text_template.render(**variables)

    # Send email
    mail(
      to: medical_provider.email,
      from: 'info@mdmat.org', # Keep existing from/reply_to if specific
      reply_to: 'medical-certification@maryland.gov',
      subject: rendered_subject,
      message_stream: 'outbound'
    ) do |format|
      format.html { render html: rendered_html_body.presence || '' }
      format.text { render plain: rendered_text_body.to_s }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send certification submission error email to #{medical_provider&.email}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end
end
