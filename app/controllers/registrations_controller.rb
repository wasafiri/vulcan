# frozen_string_literal: true

class RegistrationsController < ApplicationController
  # Require authentication for all actions except new and create
  skip_before_action :authenticate_user!, only: %i[new create]

  # Set the current user for actions that require authentication
  before_action :set_user, only: %i[edit update destroy]

  # GET /sign_up
  def new
    @user = User.new
  end

  def create
    build_user

    if @user.save
      create_session_and_cookie
      track_sign_in
      send_registration_confirmation

      redirect_to root_path, notice: 'Account created successfully. Welcome!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /edit_registration
  def edit
    @user = current_user
    redirect_to sign_in_path, alert: 'You need to sign in to access this page.' unless @user
  end

  # PATCH/PUT /update_registration
  def update
    if @user.update(registration_params)
      redirect_to root_path, notice: 'Your account was successfully updated.'
    else
      flash.now[:alert] = 'There was a problem updating your account.'
      render :edit
    end
  end

  # DELETE /delete_account
  def destroy
    if @user.destroy
      session[:user_id] = nil
      redirect_to sign_in_path, notice: 'Your account has been deleted.'
    else
      redirect_to edit_registration_path, alert: 'There was a problem deleting your account.'
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = current_user
    redirect_to sign_in_path, alert: 'You need to sign in to access this page.' unless @user
  end

  def build_user
    @user = User.new(registration_params)
    @user.type = 'Constituent'
    @user.force_password_change = false
    set_communication_preference
  end

  def set_communication_preference
    return unless params[:user]&.dig(:communication_preference) == 'letter'

    @user.communication_preference = :letter # Use symbol instead of string to properly set the enum
  end

  def create_session_and_cookie
    @session = @user.sessions.create!(
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
    cookies.signed[:session_token] = {
      value: @session.session_token,
      httponly: true,
      permanent: true
    }
  end

  def track_sign_in
    @user.track_sign_in!(request.remote_ip)
  end

  def send_registration_confirmation
    if @user.communication_preference.to_s == 'email'
      ApplicationNotificationsMailer.registration_confirmation(@user).deliver_later
    else
      Letters::LetterGeneratorService.new(
        template_type: 'registration_confirmation',
        constituent: @user,
        data: { active_vendors: Vendor.active.all }
      ).queue_for_printing
    end
  end

  def registration_params
    params.require(:user).permit(
      :email, :password, :password_confirmation,
      :first_name, :last_name, :middle_initial,
      :date_of_birth, :phone, :timezone, :locale,
      :hearing_disability, :vision_disability,
      :speech_disability, :mobility_disability, :cognition_disability,
      :communication_preference,
      # Address fields for letter notifications
      :physical_address_1, :physical_address_2,
      :city, :state, :zip_code
    )
  end
end
