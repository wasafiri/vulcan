class Identity::PasswordResetsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_user, only: [ :edit, :update ]

  def new
  end

  def edit
  end

  def create
    @user = User.find_by(email: params[:email], email_verified: true)
    if @user
      send_password_reset_email
      redirect_to sign_in_path, notice: "Reset instructions sent"
    else
      redirect_to new_identity_password_reset_path,
        alert: "Cannot reset password for unverified email"
    end
  end

  def update
    if @user.update(password_params)
      redirect_to sign_in_path, notice: "Password reset successful"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find_by_token_for!(:password_reset, params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to new_identity_password_reset_path,
      alert: "Invalid reset link"
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def send_password_reset_email
    UserMailer.with(user: @user).password_reset.deliver_later
  rescue StandardError => e
    Rails.logger.error("Failed to send password reset email: #{e.message}")
    redirect_to new_identity_password_reset_path,
      alert: "Unable to send reset email"
  end
end
