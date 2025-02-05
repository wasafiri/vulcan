class RegistrationsController < ApplicationController
  # Require authentication for all actions except new and create
  skip_before_action :authenticate_user!, only: [ :new, :create ]

  # Set the current user for actions that require authentication
  before_action :set_user, only: [ :edit, :update, :destroy ]

  # GET /sign_up
  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.type = "Constituent"

    if @user.save
      @session = @user.sessions.create!(
        user_agent: request.user_agent,
        ip_address: request.remote_ip
      )
      cookies.signed[:session_token] = { value: @session.session_token, httponly: true, permanent: true }
      @user.track_sign_in!(request.remote_ip)
      redirect_to root_path, notice: "Account created successfully. Welcome!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # GET /edit_registration
  def edit
    # @user is set by before_action
  end

  # PATCH/PUT /update_registration
  def update
    if @user.update(registration_params)
      redirect_to root_path, notice: "Your account was successfully updated."
    else
      flash.now[:alert] = "There was a problem updating your account."
      render :edit
    end
  end

  # DELETE /delete_account
  def destroy
    if @user.destroy
      session[:user_id] = nil
      redirect_to sign_in_path, notice: "Your account has been deleted."
    else
      redirect_to edit_registration_path, alert: "There was a problem deleting your account."
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user
    @user = current_user
    unless @user
      redirect_to sign_in_path, alert: "You need to sign in to access this page."
    end
  end

  def registration_params
    params.require(:user).permit(
      :email, :password, :password_confirmation,
      :first_name, :last_name, :middle_initial,
      :date_of_birth, :phone, :timezone, :locale,
      :hearing_disability, :vision_disability,
      :speech_disability, :mobility_disability, :cognition_disability
    )
  end
end
