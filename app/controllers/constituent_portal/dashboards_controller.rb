# frozen_string_literal: true

module ConstituentPortal
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_constituent!

    def show
      @applications = current_user.applications.order(created_at: :desc)

      # Set active application (most recent non-draft application)
      @active_application = @applications.where.not(status: :draft).first

      # Set draft application (most recent draft application)
      @draft_application = @applications.where(status: :draft).first

      # Get voucher information
      @voucher = @active_application&.vouchers&.available&.first

      # Calculate remaining waiting period
      @waiting_period_months = calculate_waiting_period_months

      # Get training sessions information
      @training_sessions = @active_application&.training_sessions || []
      @max_training_sessions = Policy.get('max_training_sessions') || 3
      @remaining_training_sessions = @max_training_sessions - @training_sessions.count if @active_application
    end

    private

    def require_constituent!
      return if current_user&.constituent?

      redirect_to root_path, alert: 'Access denied'
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
