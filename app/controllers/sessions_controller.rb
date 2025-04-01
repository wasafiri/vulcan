# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[new create]
  before_action :set_session, only: [:destroy]

  def index
    @sessions = current_user.sessions.order(created_at: :desc)
  end

  def new
    redirect_to after_sign_in_path if current_user
  end

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      create_and_handle_session(user)
    else
      handle_invalid_credentials
    end
  end

  def destroy
    session = current_user&.sessions&.find_by(session_token: cookies.signed[:session_token])
    if session
      session.destroy
      cookies.delete(:session_token)
      redirect_to sign_in_path, notice: 'Signed out successfully'
    else
      redirect_to sign_in_path, alert: 'No active session'
    end
  end

  private

  def set_session
    @session = Session.find_by(session_token: cookies.signed[:session_token])
  end

  def after_sign_in_path
    case current_user
    when Users::Administrator
      admin_applications_path
    when Users::Constituent
      constituent_dashboard_path
    when Users::Evaluator
      evaluators_dashboard_path
    when Users::Vendor
      vendor_dashboard_path
    else
      root_path
    end
  end

  def create_and_handle_session(user)
    @session = user.sessions.new(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    if @session.save
      cookies.signed[:session_token] = session_cookie_options(@session.session_token)
      user.track_sign_in!(request.remote_ip)
      redirect_to dashboard_for(user), notice: 'Signed in successfully'
    else
      redirect_to sign_in_path(email_hint: params[:email]), alert: 'Unable to create session'
    end
  end

  def session_cookie_options(token)
    {
      value: token,
      httponly: true,
      secure: Rails.env.production?
    }
  end

  def dashboard_for(user)
    case user
    when Users::Administrator then admin_applications_path
    when Users::Constituent then constituent_dashboard_path
    when Users::Evaluator then evaluators_dashboard_path
    when Users::Vendor then vendor_dashboard_path
    else root_path
    end
  end

  def handle_invalid_credentials
    redirect_to sign_in_path(email_hint: params[:email]), alert: 'Invalid email or password'
  end
end
