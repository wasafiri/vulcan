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

  def default_url_options
    if Rails.env.production?
      { host: MatVulcan::Application::PRODUCTION_HOST }
    else
      {}
    end
  end

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

  # --- Refactored Session Handling ---

  # Creates a session, sets the cookie, tracks sign-in, and redirects.
  # To be called after successful authentication (password or 2FA).
  def sign_in(user)
    session_record = _create_and_set_session_cookie(user)
    if session_record
      redirect_to _dashboard_for(user), notice: 'Signed in successfully'
    else
      # Handle session creation failure (though validation should prevent this)
      redirect_to sign_in_path(email_hint: user.email), alert: 'Unable to create session.'
    end
  end

  # Creates the Session record and sets the secure cookie.
  # Returns the session record on success, nil on failure.
  def _create_and_set_session_cookie(user)
    session_record = user.sessions.new(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    if session_record.save
      cookies.signed[:session_token] = _session_cookie_options(session_record.session_token)
      user.track_sign_in!(request.remote_ip) # Assuming this method exists on User model
      session_record
    else
      nil # Indicate failure
    end
  end

  # Generates options for the session cookie.
  def _session_cookie_options(token)
    {
      value: token,
      httponly: true,
      secure: Rails.env.production?,
      # Consider adding SameSite attribute for enhanced security:
      # same_site: :lax # or :strict depending on your needs
    }
  end

  # Determines the appropriate dashboard path based on user type.
  def _dashboard_for(user)
    case user
    when Users::Administrator then admin_applications_path
    when Users::Constituent then constituent_dashboard_path
    when Users::Evaluator then evaluators_dashboard_path
    when Users::Vendor then vendor_dashboard_path
    else root_path
    end
  end

  # --- Two-Factor Authentication Helpers ---

  # Completes the 2FA authentication and redirects appropriately
  def complete_two_factor_authentication(user)
    # Complete the 2FA authentication process
    TwoFactorAuth.complete_authentication(session)

    # Create the session and redirect
    session_record = _create_and_set_session_cookie(user)

    if session_record
      # Redirect to stored location or appropriate dashboard
      stored_location = TwoFactorAuth.get_return_path(session) || session.delete(:return_to)
      redirect_to stored_location || _dashboard_for(user), notice: 'Signed in successfully'
    else
      redirect_to sign_in_path, alert: 'Unable to create session.'
    end
  end

  # Checks if a 2FA authentication process has been initiated
  def two_factor_authentication_initiated?
    TwoFactorAuth.get_temp_user_id(session).present?
  end

  # Finds the user for whom 2FA is in progress
  def find_user_for_two_factor
    user_id = TwoFactorAuth.get_temp_user_id(session)
    user_id ? User.find_by(id: user_id) : nil
  end

  # Ensures a 2FA flow has been initiated
  def ensure_two_factor_initiated
    redirect_to sign_in_path unless two_factor_authentication_initiated?
  end

  # Ensures a user is not fully authenticated (used for 2FA step)
  def ensure_user_not_authenticated
    redirect_to root_path if current_user # current_user checks the final session_token cookie
  end

  # Legacy method name for backward compatibility
  alias ensure_login_initiated ensure_two_factor_initiated
end
