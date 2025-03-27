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
  end

  def find_production_session
    return unless cookies.signed[:session_token].present?

    # Only include the user without eager loading role_capabilities
    Session.includes(:user)
           .find_by(session_token: cookies.signed[:session_token])
  end

  def find_test_session
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

    # Use direct test user override as last resort
    if ENV['TEST_USER_ID'].present?
      test_user = User.find_by(id: ENV['TEST_USER_ID'])
      if test_user
        puts "TEST AUTH: Using test user override: #{test_user.email}" if ENV['DEBUG_AUTH'] == 'true'
        # Create a temporary session object to hold the user
        session_record = Session.new(user: test_user)
        return session_record
      end
    end

    # Debug logging for authentication issues
    if ENV['DEBUG_AUTH'] == 'true'
      puts 'AUTH DEBUG: current_session method called'
      puts "AUTH DEBUG: cookies: #{cookies.inspect}"
      puts "AUTH DEBUG: session_token in cookies: #{cookies[:session_token]}"
      puts "AUTH DEBUG: signed session_token: #{cookies.signed[:session_token]}" if cookies.respond_to?(:signed)

      # Check if the session record exists
      if cookies[:session_token].present?
        session_record = Session.find_by(session_token: cookies[:session_token])
        if session_record
          puts "AUTH DEBUG: Session record found with token: #{cookies[:session_token]}"
          puts "AUTH DEBUG: Session user ID: #{session_record.user_id}"
          puts "AUTH DEBUG: Session created at: #{session_record.created_at}"
        else
          puts "AUTH DEBUG: No session record found with token: #{cookies[:session_token]}"
        end
      end
    end
    nil
  end

  # Redirects unauthenticated users to the sign-in page with an alert message
  def authenticate_user!
    # Special debug for test environment
    if Rails.env.test? && ENV['DEBUG_AUTH'] == 'true'
      Rails.logger.debug "AUTHENTICATE_USER! called from #{caller[0]}"
      Rails.logger.debug "current_user: #{current_user&.email || 'nil'}"
      Rails.logger.debug "TEST_USER_ID: #{ENV['TEST_USER_ID']}"
      Rails.logger.debug "cookies: #{cookies.to_h}"
      if cookies[:session_token]
        session = Session.find_by(session_token: cookies[:session_token])
        Rails.logger.debug "Session found by token: #{session&.id || 'nil'}"
      end
    end

    return if current_user

    store_location
    redirect_to sign_in_path, alert: 'Please sign in to continue'
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
