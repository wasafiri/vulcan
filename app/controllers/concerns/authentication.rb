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
      # Try signed cookies first (production)
      if cookies.signed[:session_token]
        session_record = Session.find_by(session_token: cookies.signed[:session_token])
        return session_record&.user if session_record
      end

      # Fall back to unsigned cookies (test)
      if cookies[:session_token]
        session_record = Session.find_by(session_token: cookies[:session_token])
        return session_record&.user if session_record
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
