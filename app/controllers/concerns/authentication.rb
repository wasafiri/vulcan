module Authentication
  extend ActiveSupport::Concern

  included do
    # Enforce user authentication before accessing protected actions
    before_action :authenticate_user!

    # Make `current_user` accessible in views
    helper_method :current_user
  end

  def require_role(role)
    unless current_user&.send("#{role}?")
      redirect_to root_path, alert: "Unauthorized access"
    end
  end

  private

  # Retrieves the currently logged-in user based on the session_token stored in signed cookies
  def current_user
    @current_user ||= begin
      if cookies.signed[:session_token]
        # Find the session record using the session_token
        session_record = Session.find_by(session_token: cookies.signed[:session_token])

        # Return the associated user if the session is valid
        session_record&.user
      else
        nil
      end
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

  # Restricts access to evaluator users only
  def require_evaluator!
    unless current_user.evaluator?
      redirect_to root_path, alert: "Unauthorized access"
    end
  end
end
