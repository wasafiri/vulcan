# frozen_string_literal: true

module Admin
  class RecoveryRequestsController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin
    before_action :set_recovery_request, only: [:show, :approve]

    def index
      @recovery_requests = RecoveryRequest.includes(:user).where(status: 'pending').order(created_at: :desc)
    end

    def show
      # Simply renders the show view with the recovery request found by set_recovery_request
    end

    def approve
      # Transaction to ensure user's credentials are deleted if and only if the status is updated
      ActiveRecord::Base.transaction do
        # Delete all the user's WebAuthn credentials
        @recovery_request.user.webauthn_credentials.destroy_all

        # Update the recovery request status
        @recovery_request.update!(
          status: 'approved',
          resolved_at: Time.current,
          resolved_by_id: current_user.id
        )

        # Notify the user
        notify_user_of_approval
      end

      redirect_to admin_recovery_requests_path, notice: 'Security key recovery request approved successfully. The user can now register a new security key.'
    end

    private

    def set_recovery_request
      @recovery_request = RecoveryRequest.find(params[:id])
    end

    def ensure_admin
      unless current_user.admin?
        redirect_to root_path, alert: 'You are not authorized to access this page.'
      end
    end

    def notify_user_of_approval
      # Send email notification to the user
      # You may want to implement a proper mailer for this
      # For now, using the NotifyAdminsJob as an example of how you might queue a job
      NotifyAdminsJob.perform_later(
        subject: 'Security Key Recovery Request Approved',
        message: "Your security key recovery request has been approved. You can now sign in with your password only and register a new security key.",
        category: 'security_recovery',
        resource_id: @recovery_request.user_id,
        resource_type: 'User'
      )
    end
  end
end
