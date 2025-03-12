class PasswordsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_user, only: [ :edit, :update ]

  def new
  end

  def create
    @user = User.find_by(email: params[:email])
    if @user
      # Generate reset token and send email
      @user.generate_password_reset_token!
      # UserMailer.password_reset(@user).deliver_later # You'll need to create this mailer
      redirect_to sign_in_path, notice: "Check your email for password reset instructions."
    else
      redirect_to new_password_path, alert: "Email address not found."
    end
  end

  def edit
    # The form to enter new password
    # @user is set by set_user
  end

  def update
    if params[:password] == params[:password_confirmation]
      @user = current_user
      if @user&.authenticate(params[:password_challenge])
        if @user.update(password: params[:password])
          redirect_to sign_in_path, notice: "Password successfully updated"
        else
          flash.now[:alert] = "Unable to update password"
          render :edit, status: :unprocessable_entity
        end
      else
        flash.now[:alert] = "Current password is incorrect"
        render :edit, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = "New password and confirmation don't match"
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def set_user
    if params[:token].present?
      @user = User.find_by(reset_password_token: params[:token])
      redirect_to new_password_path, alert: "Invalid or expired reset link." unless @user
    end
  end
end
