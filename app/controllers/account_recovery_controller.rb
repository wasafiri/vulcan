# frozen_string_literal: true

class AccountRecoveryController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[new create confirmation]

  def new
    # Renders the form for requesting security key recovery
  end

  def create
    # Find user by email
    @user = User.find_by_email(params[:email])

    if @user.present?
      # Create a recovery request record
      recovery_request = create_recovery_request(@user)

      # Notify administrators of the recovery request
      notify_admins_of_recovery_request(recovery_request)
    end

    # We don't want to reveal if an email exists in our system
    # So we show the confirmation page regardless
    redirect_to account_recovery_confirmation_path
  end

  def confirmation
    # Renders confirmation page
  end

  private

  def create_recovery_request(user)
    # Record the recovery request in the database
    RecoveryRequest.create!(
      user: user,
      status: 'pending',
      details: params[:details],
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    # Return the recovery request object
  end

  def notify_admins_of_recovery_request(recovery_request)
    # Queue a job to notify admins (implementation depends on your notification system)
    NotifyAdminsJob.perform_later(
      subject: 'Security Key Recovery Request',
      message: "User #{recovery_request.user.email} has requested security key recovery. Please review this request in the admin panel.",
      category: 'security_recovery',
      resource_id: recovery_request.id,
      resource_type: 'RecoveryRequest'
    )
  end
end
