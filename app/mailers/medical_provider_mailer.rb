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
  def certification_rejected
    template_name = 'medical_provider_certification_rejected'
    puts "DEBUG: certification_rejected - Looking for template: #{template_name}" # Debug line
    begin
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
      puts "DEBUG: certification_rejected - Found template: #{text_template.inspect}" # Debug line
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email template (text format) not found for #{template_name}"
    end

    # Prepare variables
    application = params[:application]
    rejection_reason = params[:rejection_reason]

    constituent = application.user
    remaining_attempts = 8 - application.total_rejections

    variables = {
      constituent_full_name: constituent.full_name,
      application_id: application.id,
      rejection_reason: rejection_reason,
      remaining_attempts: remaining_attempts
    }.compact
    puts "DEBUG: certification_rejected - Variables: #{variables.inspect}" # Debug line

    # Render subject and body
    rendered_subject, rendered_text_body = text_template.render(**variables)
    puts "DEBUG: certification_rejected - Rendered Subject: #{rendered_subject.inspect}" # Debug line
    puts "DEBUG: certification_rejected - Rendered Body: #{rendered_text_body.inspect}" # Debug line

    # Send email
    mail(
      to: application.medical_provider_email,
      from: 'info@mdmat.org',
      reply_to: 'medical-certification@maryland.gov',
      subject: rendered_subject,
      message_stream: 'outbound'
    ) do |format|
      format.text { render plain: rendered_text_body.to_s }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send certification rejected email for application #{params[:application]&.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  # Request certification from a medical provider
  # @param application [Application] The application requiring certification
  # @param timestamp [String] ISO8601 timestamp of when the request was made
  # @param notification_id [Integer] ID of the notification record for tracking
  def request_certification
    template_name = 'medical_provider_request_certification'
    puts "DEBUG: request_certification - Looking for template: #{template_name}" # Debug line
    begin
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
      puts "DEBUG: request_certification - Found template: #{text_template.inspect}" # Debug line
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email template (text format) not found for #{template_name}"
    end

    # Prepare variables
    application = params[:application]
    timestamp = params[:timestamp]
    notification_id = params[:notification_id]

    constituent = application.user
    timestamp_formatted = (timestamp ? Time.iso8601(timestamp) : Time.current).strftime('%B %d, %Y at %I:%M %p %Z')
    request_count = application.medical_certification_request_count || 1
    request_count_message = request_count > 1 ? "This is a follow-up request (Request ##{request_count})" : ''
    constituent_dob_formatted = constituent.date_of_birth&.strftime('%m/%d/%Y') || 'Not Provided'
    # Basic address formatting, could be enhanced
    constituent_address_formatted = [
      constituent.physical_address_1,
      constituent.physical_address_2,
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
    }.compact
    puts "DEBUG: request_certification - Variables: #{variables.inspect}" # Debug line

    # Render subject and body
    rendered_subject, rendered_text_body = text_template.render(**variables)
    puts "DEBUG: request_certification - Rendered Subject: #{rendered_subject.inspect}" # Debug line
    puts "DEBUG: request_certification - Rendered Body: #{rendered_text_body.inspect}" # Debug line

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
      format.text { render plain: rendered_text_body.to_s }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send request certification email for application #{params[:application]&.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  # Notify a medical provider about an error during certification submission
  # @param medical_provider [User] The medical provider who sent the email
  # @param application [Application, nil] The associated application, if found
  # @param error_type [Symbol] The type of error (:provider_not_found, :invalid_certification_request, etc.)
  # @param message [String] The error message
  def certification_submission_error
    template_name = 'medical_provider_certification_submission_error'
    puts "DEBUG: certification_submission_error - Looking for template: #{template_name}" # Debug line
    begin
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
      puts "DEBUG: certification_submission_error - Found template: #{text_template.inspect}" # Debug line
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email template (text format) not found for #{template_name}"
    end

    # Prepare variables
    medical_provider = params[:medical_provider]
    application = params[:application]
    message = params[:message]

    variables = {
      medical_provider_email: medical_provider.email,
      error_message: message,
      constituent_full_name: application&.user&.full_name,
      application_id: application&.id
    }.compact
    puts "DEBUG: certification_submission_error - Variables: #{variables.inspect}" # Debug line

    # Render subject and body
    rendered_subject, rendered_text_body = text_template.render(**variables)
    puts "DEBUG: certification_submission_error - Rendered Subject: #{rendered_subject.inspect}" # Debug line
    puts "DEBUG: certification_submission_error - Rendered Body: #{rendered_text_body.inspect}" # Debug line

    # Send email
    mail(
      to: medical_provider.email,
      from: 'info@mdmat.org',
      reply_to: 'medical-certification@maryland.gov',
      subject: rendered_subject,
      message_stream: 'outbound'
    ) do |format|
      format.text { render plain: rendered_text_body.to_s }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send certification submission error email to #{params[:medical_provider]&.email}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end
end
