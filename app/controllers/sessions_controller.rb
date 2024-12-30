class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[new create]

  before_action :set_session, only: [ :destroy ]

  def index
    @sessions = current_user.sessions.order(created_at: :desc)
  end

  def new
  end

# app/controllers/sessions_controller.rb
def create
  user = User.find_by(email: params[:email])

  if user&.authenticate(params[:password])
    @session = user.sessions.new
    @session.user_agent = request.user_agent
    @session.ip_address = request.remote_ip

    if @session.save
      cookies.signed.permanent[:session_token] = { value: @session.session_token, httponly: true }
      user.track_sign_in!(request.remote_ip)

      # Redirect based on user type
      redirect_path = case user
      when Admin
          admin_root_path
      when Constituent
          constituent_dashboard_path
      when Evaluator
          evaluator_dashboard_path
      when Vendor
          vendor_dashboard_path
      else
          root_path
      end

      redirect_to redirect_path, notice: "Signed in successfully"
    else
      redirect_to sign_in_path(email_hint: params[:email]),
        alert: "Unable to create session. Please try again."
    end
  else
    redirect_to sign_in_path(email_hint: params[:email]),
      alert: "That email or password is incorrect."
  end
end

  def destroy
    session = current_user.sessions.find_by(session_token: cookies.signed[:session_token])
    if session
      session.destroy
      cookies.delete :session_token
      redirect_to sign_in_path, notice: "Signed out successfully"
    else
      redirect_to root_path, alert: "Session not found"
    end
  end

  private

  def set_current_attributes
    Current.set_attributes(request)
  end

  def set_session
    @session = Session.find_by(session_token: cookies.signed[:session_token])
  end
end
