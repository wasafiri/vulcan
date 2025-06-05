class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[new create]
  def new
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('sign_in_form', partial: 'sessions/form')
      end
      format.html { redirect_to(_dashboard_for(current_user)) if current_user }
    end
  end

  def create
    user = User.find_by_email(params[:email])

    if user && user.authenticate(params[:password])
      if user.second_factor_enabled?
        # Store user ID temporarily and redirect to 2FA step
        cookies.delete(:session_token) # Ensure no old session interferes
        TwoFactorAuth.clear_challenge(session) # Clear any stale challenge
        TwoFactorAuth.store_temp_user_id(session, user.id)
        TwoFactorAuth.store_return_path(session, session[:return_to])
        redirect_to verify_method_two_factor_authentication_path(type: 'webauthn') and return
      else
        # User doesn't have 2FA, sign them in directly using the ApplicationController helper
        sign_in(user) and return # This now calls the refactored method in ApplicationController
        # The sign_in method handles the redirect
      end
    else
      handle_invalid_credentials and return # Keep existing invalid credential handling
    end
  end

  def destroy
    # Clean up any 2FA in progress
    TwoFactorAuth.complete_authentication(session) if two_factor_authentication_initiated?

    # Find and destroy the current session if it exists
    current_user&.sessions&.find_by(session_token: cookies.signed[:session_token])&.destroy

    # Always clear the session cookie
    cookies.delete(:session_token)

    # Handle different response formats appropriately
    respond_to do |format|
      format.html { redirect_to sign_in_path, notice: 'Signed out successfully' }
      format.turbo_stream { redirect_to sign_in_path, notice: 'Signed out successfully' }
    end
  end

  private

  def handle_invalid_credentials
    # Add user feedback for failed login attempts if User model supports it
    # user = User.find_by(email: params[:email])
    # user&.track_failed_attempt!(request.remote_ip) if user # Assuming track_failed_attempt! exists
    redirect_to sign_in_path(email_hint: params[:email]), alert: 'Invalid email or password'
  end
end
