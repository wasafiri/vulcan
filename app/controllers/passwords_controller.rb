# frozen_string_literal: true

# Handles password reset and forced password change functionality
class PasswordsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_user, only: %i[edit update]

  def new; end

  def edit
    # The form to enter new password
    # @user is set by set_user
  end

  def create
    @user = User.find_by_email(params[:email])
    if @user
      # Generate reset token and send email
      @user.generate_password_reset_token!
      # UserMailer.password_reset(@user).deliver_later # You'll need to create this mailer
      redirect_to sign_in_path, notice: 'Check your email for password reset instructions.'
    else
      redirect_to new_password_path, alert: 'Email address not found.'
    end
  end

  def update
    # Use current_user directly as we are updating the logged-in user's password
    @user = current_user

    # Check if user exists and current password is correct
    if @user&.authenticate(params[:password_challenge])
      # Check if new password and confirmation match
      if params[:password] == params[:password_confirmation]
        # Attempt to update the password
        if @user.update(password: params[:password], force_password_change: false)
          # Successful update
          flash[:notice] = 'Password successfully updated.'
          respond_to do |format|
            # Turbo Stream response for immediate feedback
            format.turbo_stream
            # HTML fallback (though Turbo should handle this)
            format.html { redirect_to sign_in_path, notice: flash[:notice] }
          end
        else
          # Update failed (e.g., validation error on user model)
          flash.now[:alert] = 'Unable to update password. Please check requirements.'
          render :edit, status: :unprocessable_entity
        end
      else
        # New passwords don't match
        flash.now[:alert] = 'New password and confirmation do not match.'
        render :edit, status: :unprocessable_entity
      end
    else
      # Current password incorrect or user not found (shouldn't happen if logged in)
      flash.now[:alert] = 'Current password is incorrect.'
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def set_user
    return unless params[:token].present?

    @user = User.find_by_token_for(:password_reset, params[:token])
    redirect_to new_password_path, alert: 'Invalid or expired reset link.' unless @user
  end
end
