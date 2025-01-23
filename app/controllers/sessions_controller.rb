class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create ]
  before_action :set_session, only: [ :destroy ]

  def index
    @sessions = current_user.sessions.order(created_at: :desc)
  end

  def new
    redirect_to after_sign_in_path if current_user
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      @session = user.sessions.new(
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      )

      if @session.save
        cookies.signed[:session_token] = {
          value: @session.session_token,
          httponly: true,
          secure: Rails.env.production?
        }

        user.track_sign_in!(request.remote_ip)

        redirect_path = case user
        when Admin
          admin_applications_path
        when Constituent
          constituent_dashboard_path
        when Evaluator
          evaluators_dashboard_path
        when Vendor
          vendor_dashboard_path
        else
          root_path
        end

        redirect_to redirect_path, notice: "Signed in successfully"
      else
        redirect_to sign_in_path(email_hint: params[:email]),
          alert: "Unable to create session"
      end
    else
      redirect_to sign_in_path(email_hint: params[:email]),
        alert: "Invalid email or password"
    end
  end

  def destroy
    if session = current_user&.sessions&.find_by(session_token: cookies.signed[:session_token])
      session.destroy
      cookies.delete(:session_token)
      redirect_to sign_in_path, notice: "Signed out successfully"
    else
      redirect_to sign_in_path, alert: "No active session"
    end
  end

  private

  def set_session
    @session = Session.find_by(session_token: cookies.signed[:session_token])
  end

  def after_sign_in_path
    case current_user
    when Admin
      admin_applications_path
    when Constituent
      constituent_dashboard_path
    when Evaluator
      evaluators_dashboard_path
    when Vendor
      vendor_dashboard_path
    else
      root_path
    end
  end
end
