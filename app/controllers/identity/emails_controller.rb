class Identity::EmailsController < ApplicationController
  before_action :set_user

  def edit
  end

  def update
    if @user.authenticate(params[:password_challenge]) && @user.update(email_params)
      handle_email_update
    else
      flash.now[:alert] = @user.errors.full_messages.first || "Invalid password"
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def email_params
    params.require(:user).permit(:email)
  end

  def handle_email_update
    if @user.email_previously_changed?
      @user.update!(email_verified: false)
      send_verification_email
      redirect_to root_path, notice: "Email updated. Please check your inbox for verification."
    else
      redirect_to root_path
    end
  end

  def send_verification_email
    UserMailer.with(user: @user).email_verification.deliver_later
  rescue StandardError => e
    Rails.logger.error("Failed to send verification email: #{e.message}")
    redirect_to edit_identity_email_path, alert: "Unable to send verification email."
  end
end
