# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @token = @user.generate_token_for(:password_reset)
    @reset_url = edit_password_url(token: @token)

    mail(
      to: @user.email,
      subject: 'Reset your password',
      template_path: 'user_mailer',
      template_name: 'password_reset',
      message_stream: 'outbound'
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send password reset email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) # Add backtrace for better debugging
    raise e if Rails.env.test? # Re-raise in test environment for better error visibility
  end

  def email_verification
    @user = params[:user]
    # Using the user verification path within constituent portal
    @token = @user.generate_token_for(:email_verification)
    @verification_url = verify_constituent_portal_application_url(id: @user.id, token: @token)

    mail(
      to: @user.email,
      subject: 'Verify your email',
      template_path: 'user_mailer',
      template_name: 'email_verification',
      message_stream: 'outbound'
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send verification email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) # Add backtrace for better debugging
    raise e if Rails.env.test? # Re-raise in test environment for better error visibility
  end
end
