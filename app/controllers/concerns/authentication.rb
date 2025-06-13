# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user
    before_action :authenticate_user!
  end

  def require_role(role)
    return if current_user&.send("#{role}?")

    redirect_to root_path, alert: 'Unauthorized access'
  end

  private

  # Retrieves the currently logged-in user based on the session_token stored in cookies
  def current_user
    return @current_user if defined?(@current_user)

    # Load current session first to avoid redundant DB queries
    current_session

    # Return the already loaded user from the session if possible
    @current_user = @current_session&.user
    
    # Set Current.user for the request context - needed for verify_authentication_state
    Current.user = @current_user if @current_user.present?
    
    @current_user
  end

  # Load and cache the current session
  def current_session
    return @current_session if defined?(@current_session)

    @current_session = if Rails.env.test?
                         find_test_session
                       else
                         # Production environment - use signed cookies only
                         find_production_session
                       end

    # Check for expired session
    if @current_session && @current_session.respond_to?(:expired?) && @current_session.expired?
      @current_session = nil
      cookies.delete(:session_token)
    end

    @current_session
  end

  def find_production_session
    return unless cookies.signed[:session_token].present?

    # Only include the user without eager loading role_capabilities
    Session.includes(:user)
           .find_by(session_token: cookies.signed[:session_token])
  end

  def find_test_session
    # Check Current.test_user_id FIRST (set by authentication helpers)
    if defined?(Current) && Current.test_user_id.present?
      test_user = User.find_by(id: Current.test_user_id)
      if test_user
        return Session.new(user: test_user)
      end
    end

    # Check for test user header SECOND
    test_user_id = request.headers['X-Test-User-Id'] || request.headers['HTTP_X_TEST_USER_ID']
    
    if test_user_id.present?
      test_user = User.find_by(id: test_user_id)
      if test_user
        return Session.new(user: test_user)
      end
    end

    # Check ENV['TEST_USER_ID'] as fallback THIRD
    if ENV['TEST_USER_ID'].present?
      test_user = User.find_by(id: ENV['TEST_USER_ID'])
      if test_user
        return Session.new(user: test_user)
      end
    end

    session_record = nil

    # Try signed cookies first
    if cookies.signed[:session_token].present?
      session_record = Session.includes(:user)
                              .find_by(session_token: cookies.signed[:session_token])
      return session_record if session_record
    end

    # Fall back to unsigned cookies
    if cookies[:session_token].present?
      session_record = Session.includes(:user)
                              .find_by(session_token: cookies[:session_token])
      return session_record if session_record
    end

    nil
  end

  # Redirects unauthenticated users to the sign-in page with an alert message
  def authenticate_user!
    return if current_user.present?

    store_location
    redirect_to sign_in_path, alert: 'Please sign in to continue' and return
  end

  def store_location
    session[:return_to] = request.fullpath if request.get? || request.head?
  end

  # Restricts access to admin users only
  def require_admin!
    return if current_user.admin?

    redirect_to root_path, alert: 'Unauthorized access'
  end

  def require_evaluator!
    return if current_user.evaluator? || current_user.admin?

    redirect_to root_path, alert: 'Unauthorized access'
  end


end
