# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @token = @user.generate_token_for(:password_reset)
    @reset_url = edit_identity_password_reset_url(token: @token)

    mail(
      to: @user.email,
      subject: 'Reset your password',
      template_path: 'user_mailer',
      template_name: 'password_reset',
      message_stream: 'outbound'
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send password reset email: #{e.message}")
  end

  def email_verification
    @user = params[:user]
    @token = @user.generate_token_for(:email_verification)
    @verification_url = identity_email_verification_url(token: @token)

    mail(
      to: @user.email,
      subject: 'Verify your email',
      template_path: 'user_mailer',
      template_name: 'email_verification',
      message_stream: 'outbound'
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send verification email: #{e.message}")
  end
end
