class Identity::EmailVerificationsController < ApplicationController
  skip_before_action :authenticate_user!, only: :show
  before_action :set_user, only: :show

  def show
    @user.update!(email_verified: true)
    redirect_to root_path, notice: "Email address verified successfully."
  end

  def create
    send_email_verification
    redirect_to root_path, notice: "Verification email sent."
  end

  private

  def set_user
    @user = User.find_by_token_for!(:email_verification, params[:token])
  rescue ActiveRecord::RecordNotFound
    redirect_to edit_identity_email_path, alert: "Invalid verification link."
  end

  def send_email_verification
    UserMailer.with(user: current_user).email_verification.deliver_later
  end
end
