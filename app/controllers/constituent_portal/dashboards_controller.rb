# frozen_string_literal: true

module ConstituentPortal
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_constituent!
    # Make these methods available as helper methods in views
    helper_method :get_latest_rejection_reason, :get_latest_rejection_date, :can_resubmit_proof?

    def show
      # Load user's own applications
      @applications = current_user.applications.order(created_at: :desc)

      # If no applications found, try a more direct approach to handle potential type mismatches
      if @applications.empty?
        Rails.logger.info "No applications found via association for user #{current_user.id}, trying direct query"
        @applications = Application.where(user_id: current_user.id).order(created_at: :desc)
      end

      # Load applications where the user is a guardian
      @managed_applications = Application.where(managing_guardian_id: current_user.id).order(created_at: :desc)

      # Log for debugging
      Rails.logger.info "Dashboard loaded guardian applications for user #{current_user.id}: " \
                        "#{@managed_applications.count} managed applications"

      # Set active application (most recent non-draft application)
      @active_application = @applications.where.not(status: :draft).first

      # Set draft application (most recent draft application)
      @draft_application = @applications.where(status: :draft).first

      # Log for debugging
      Rails.logger.info "Dashboard loaded for user #{current_user.id}: " \
                        "#{@applications.count} total applications, " \
                        "active_application_id=#{@active_application&.id}, " \
                        "draft_application_id=#{@draft_application&.id}"

      # Get voucher information
      @voucher = @active_application&.vouchers&.available&.first

      # Calculate remaining waiting period
      @waiting_period_months = calculate_waiting_period_months

      # Get training sessions information
      @training_sessions = @active_application&.training_sessions || []
      @max_training_sessions = Policy.get('max_training_sessions') || 3
      @remaining_training_sessions = @max_training_sessions - @training_sessions.count if @active_application

      # Get proof status information
      return unless @active_application

      @max_proof_submissions = Policy.get('max_proof_submissions') || 3

      # Income Proof Information
      @income_proof_status = @active_application.income_proof_status
      @income_proof_rejection_reason = get_latest_rejection_reason(@active_application, 'income')
      @income_proof_rejection_date = get_latest_rejection_date(@active_application, 'income')
      @income_proof_submission_count = count_proof_submissions(@active_application, 'income')
      @can_resubmit_income_proof = can_resubmit_proof?(@active_application, 'income', @max_proof_submissions)

      # Residency Proof Information
      @residency_proof_status = @active_application.residency_proof_status
      @residency_proof_rejection_reason = get_latest_rejection_reason(@active_application, 'residency')
      @residency_proof_rejection_date = get_latest_rejection_date(@active_application, 'residency')
      @residency_proof_submission_count = count_proof_submissions(@active_application, 'residency')
      @can_resubmit_residency_proof = can_resubmit_proof?(@active_application, 'residency', @max_proof_submissions)

      # Get recent activities
      @recent_activities = get_recent_activities(@active_application)
    end

    protected

    # Helper methods available to views
    def get_latest_rejection_reason(application, proof_type)
      latest_review = application.proof_reviews.where(proof_type: proof_type, status: :rejected)
                                 .order(created_at: :desc).first
      latest_review&.notes || latest_review&.rejection_reason
    end

    def get_latest_rejection_date(application, proof_type)
      latest_review = application.proof_reviews.where(proof_type: proof_type, status: :rejected)
                                 .order(created_at: :desc).first
      latest_review&.created_at
    end

    def can_resubmit_proof?(application, proof_type, max_submissions)
      # Only allow resubmission for rejected proofs
      status_method = "#{proof_type}_proof_status_rejected?"
      return false unless application.send(status_method)

      # Check if under the maximum number of allowed resubmissions
      submission_count = count_proof_submissions(application, proof_type)
      submission_count < max_submissions
    end

    private

    def require_constituent!
      return if current_user&.constituent?

      redirect_to root_path, alert: 'Access denied'
    end

    def count_proof_submissions(application, proof_type)
      application.events.where(action: 'proof_submitted', metadata: { proof_type: proof_type }).count
    end

    def get_recent_activities(application)
      # Get both proof submissions and reviews in a unified format
      ConstituentPortal::Activity.from_events(application).first(10)
    end

    def calculate_waiting_period_months
      return nil unless @active_application

      waiting_period_years = Policy.get('waiting_period_years') || 3
      waiting_period_end_date = @active_application.application_date + waiting_period_years.years

      # Calculate months between now and waiting period end date
      months_remaining = ((waiting_period_end_date.year - Time.current.year) * 12) +
                         (waiting_period_end_date.month - Time.current.month)

      # Return 0 if waiting period has passed
      [months_remaining, 0].max
    end
  end
end
