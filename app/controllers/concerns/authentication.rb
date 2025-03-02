module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user
    before_action :authenticate_user!
  end

  def require_role(role)
    unless current_user&.send("#{role}?")
      redirect_to root_path, alert: "Unauthorized access"
    end
  end

  private

  # Retrieves the currently logged-in user based on the session_token stored in cookies
  def current_user
    @current_user ||= begin
      # Special handling for test environment
      if Rails.env.test?
        # Direct test user override - highest priority
        if ENV["TEST_USER_ID"].present?
          test_user = User.find_by(id: ENV["TEST_USER_ID"])
          if test_user
            puts "TEST AUTH: Using test user override: #{test_user.email}" if ENV["DEBUG_AUTH"] == "true"
            return test_user
          end
        end

        # Try signed cookies
        if cookies.signed[:session_token]
          session_record = Session.find_by(session_token: cookies.signed[:session_token])
          return session_record&.user if session_record
        end

        # Fall back to unsigned cookies
        if cookies[:session_token]
          session_record = Session.find_by(session_token: cookies[:session_token])
          return session_record&.user if session_record
        end

        # Debug logging for authentication issues
        if ENV["DEBUG_AUTH"] == "true"
          puts "AUTH DEBUG: current_user method called"
          puts "AUTH DEBUG: cookies: #{cookies.inspect}"
          puts "AUTH DEBUG: session_token in cookies: #{cookies[:session_token]}"
          if cookies.respond_to?(:signed)
            puts "AUTH DEBUG: signed session_token: #{cookies.signed[:session_token]}"
          end

          # Check if the session record exists
          if cookies[:session_token]
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
      else
        # Production environment - use signed cookies only
        if cookies.signed[:session_token]
          session_record = Session.find_by(session_token: cookies.signed[:session_token])
          return session_record&.user if session_record
        end
      end

      # No valid session found
      nil
    end
  end

  # Redirects unauthenticated users to the sign-in page with an alert message
  def authenticate_user!
    return if current_user
    store_location
    redirect_to sign_in_path, alert: "Please sign in to continue"
  end

  def store_location
    session[:return_to] = request.fullpath if request.get? || request.head?
  end

  # Restricts access to admin users only
  def require_admin!
    unless current_user.admin?
      redirect_to root_path, alert: "Unauthorized access"
    end
  end

  # Restricts access to evaluator and admin users only
  def require_evaluator!
    unless current_user.evaluator? || current_user.admin?
      redirect_to root_path, alert: "Unauthorized access"
    end
  end
end
