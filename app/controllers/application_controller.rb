# frozen_string_literal: true

# Base controller that all other controllers inherit from
# Includes authentication, CSRF protection, and password change enforcement
class ApplicationController < ActionController::Base
  include Authentication
  protect_from_forgery with: :exception

  # Include our helpers
  helper PasswordFieldHelper
  helper EmailStatusHelper

  before_action :check_password_change_required

  private

  def check_password_change_required
    return unless current_user&.force_password_change?

    # Skip the check on the password edit page and during password update
    return if controller_name == 'passwords' && %w[edit update].include?(action_name)

    # Store the current path to return after password change
    store_location if request.get? && !request.xhr?

    # Redirect to password change form with notice
    redirect_to edit_password_path, notice: 'For security reasons, you must change your password before continuing.'
  end
end
