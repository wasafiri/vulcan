# frozen_string_literal: true

class WelcomeController < ApplicationController
  before_action :authenticate_user!

  # GET /welcome
  # First-time welcome page after registration
  def index
    @user = current_user
    @has_webauthn = @user.webauthn_credentials.exists?

    # If user already has 2FA set up, redirect to dashboard
    if @has_webauthn && params[:force] != 'true'
      redirect_to_appropriate_dashboard
    end
  end

  private

  def redirect_to_appropriate_dashboard
    if current_user.constituent?
      redirect_to constituent_portal_dashboard_path
    elsif current_user.vendor?
      redirect_to vendor_dashboard_path
    elsif current_user.evaluator? 
      redirect_to evaluators_dashboard_path
    elsif current_user.trainer?
      redirect_to trainers_dashboard_path
    elsif current_user.admin?
      redirect_to admin_dashboard_path
    else
      redirect_to root_path
    end
  end
end
