# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Authentication
  protect_from_forgery with: :exception

  private

  def authenticate_user!
    unless current_user
      redirect_to sign_in_path, alert: "Please sign in to continue"
    end
  end

  def current_user
    @current_user ||= begin
      if cookies.signed[:session_token]
        session_record = Session.find_by(session_token: cookies.signed[:session_token])
        session_record&.user
      end
    end
  end
  helper_method :current_user
end
