# frozen_string_literal: true

class UserMailer < ApplicationMailer
  # NOTE: These simple emails don't use shared partials like header/footer.

  def password_reset
    user = params[:user]
    token = user.generate_token_for(:password_reset)
    reset_url = edit_password_url(token: token, host: default_url_options[:host]) # Ensure host is included

    template_name = 'user_mailer_password_reset'
    begin
      # Only find the text template as per project strategy
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate (text format) for #{template_name}: #{e.message}"
      raise "Email template (text format) not found for #{template_name}"
    end

    # Prepare variables
    variables = {
      user_email: user.email,
      reset_url: reset_url
    }.compact

    Rails.logger.debug { "DEBUG: About to call render on text_template: #{text_template.inspect}" } # Debug line
    # Render subject and body from the text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Send email
    text_body = rendered_text_body.to_s
    Rails.logger.debug { "DEBUG: Preparing to send password_reset email with content: #{text_body.inspect}" }

    mail(
      to: user.email,
      subject: rendered_subject,
      message_stream: 'user-email',
      body: text_body,
      content_type: 'text/plain'
    )
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: user, # Use local variable if available
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name, # Use local variable
        variables: variables, # Use local variable
        backtrace: e.backtrace&.first(5)
      }
    )
    raise e # Re-raise after logging
  end

  def email_verification
    user = params[:user]
    token = user.generate_token_for(:email_verification)
    # Using the user verification path within constituent portal - ensure host is included
    verification_url = verify_constituent_portal_application_url(id: user.id, token: token,
                                                                 host: default_url_options[:host])

    template_name = 'user_mailer_email_verification'
    begin
      # Only find the text template as per project strategy
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate (text format) for #{template_name}: #{e.message}"
      raise "Email template (text format) not found for #{template_name}"
    end

    # Prepare variables
    variables = {
      user_email: user.email,
      verification_url: verification_url
    }.compact

    Rails.logger.debug { "DEBUG: About to call render on text_template: #{text_template.inspect}" } # Debug line
    # Render subject and body from the text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Send email
    text_body = rendered_text_body.to_s
    Rails.logger.debug { "DEBUG: Preparing to send email_verification email with content: #{text_body.inspect}" }

    mail(
      to: user.email,
      subject: rendered_subject,
      message_stream: 'outbound', # Keep existing stream or adjust if needed
      body: text_body,
      content_type: 'text/plain'
    )
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: user, # Use local variable if available
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name, # Use local variable
        variables: variables, # Use local variable
        backtrace: e.backtrace&.first(5)
      }
    )
    raise e # Re-raise after logging
  end
end
