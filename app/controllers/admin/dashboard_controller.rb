# frozen_string_literal: true

module Admin
  class DashboardController < ApplicationController
    before_action :require_admin!
    include Pagy::Backend

    def index
      load_dashboard_counts
      scope = build_application_scope
      scope = apply_filter(scope, params[:filter])
      @pagy, @applications = pagy(scope, items: 20)
    end

    private

    def load_dashboard_counts
      @current_fiscal_year       = fiscal_year
      @total_users_count         = User.count
      @ytd_constituents_count    = Application.where(created_at: fiscal_year_start..).count
      @open_applications_count   = Application.active.count
      @pending_services_count    = Application.where(status: :approved).count

      # Calculate training requests count properly, counting distinct applications
      # to avoid duplicate counting if there are multiple notifications for the same application
      @training_requests_count = Notification.where(action: 'training_requested')
                                             .where(notifiable_type: 'Application')
                                             .select(:notifiable_id)
                                             .distinct
                                             .count

      @proofs_needing_review_count = Application.where(income_proof_status: :not_reviewed)
                                                .or(Application.where(residency_proof_status: :not_reviewed))
                                                .count
      @medical_certs_to_review_count = Application.where(medical_certification_status: 'received').count
    end

    def build_application_scope
      Application.includes(:user, :income_proof_attachment, :residency_proof_attachment)
                 .where.not(status: %i[rejected archived])
                 .order(created_at: :desc)
    end

    def apply_filter(scope, filter)
      case filter
      when 'in_progress'
        scope.where(status: :in_progress)
      when 'approved'
        scope.where(status: :approved)
      when 'proofs_needing_review'
        scope.where(income_proof_status: 0)
             .or(scope.where(residency_proof_status: 0))
      when 'awaiting_medical_response'
        scope.where(status: :awaiting_documents)
      when 'training_requests'
        # Filter applications with training request notifications
        application_ids = Notification.where(action: 'training_requested')
                                      .where(notifiable_type: 'Application')
                                      .pluck(:notifiable_id)
        # Debug output to help diagnose the issue
        Rails.logger.debug { "Training requests filter found IDs: #{application_ids.inspect}" }

        # The issue might be that the application is filtered out by the base scope
        # Use unscoped to avoid default scopes for just this specific filter
        if application_ids.present?
          # Ensure we include applications regardless of their status
          Application.where(id: application_ids)
        else
          # Empty result set if no training requests found
          scope.none
        end
      else
        scope
      end
    end

    def fiscal_year
      current_date = Date.current
      current_date.month >= 7 ? current_date.year : current_date.year - 1
    end

    def fiscal_year_start
      year = fiscal_year
      Date.new(year, 7, 1)
    end
  end
end
