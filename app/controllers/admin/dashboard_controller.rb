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

    def load_dashboard_counts
      # Ensure all instance variable keys are sanitized to prevent errors with special characters
      safe_assign(:current_fiscal_year, fiscal_year)
      safe_assign(:total_users_count, User.count)
      safe_assign(:ytd_constituents_count, Application.where(created_at: fiscal_year_start..).count)

      # Add debug logging for application counts
      active_count = Application.active.count
      approved_count = Application.where(status: :approved).count
      Rails.logger.info "Dashboard counts - Active: #{active_count}, Approved: #{approved_count}"

      # Calculate medical certs and proofs needing review counts
      proofs_needing_review_count = Application.where(income_proof_status: :not_reviewed)
                                               .or(Application.where(residency_proof_status: :not_reviewed))
                                               .distinct
                                               .count
      medical_certs_to_review_count = Application.where(medical_certification_status: 'received').count

      # Add detailed logging for troubleshooting
      Rails.logger.info "Medical certifications needing review: #{medical_certs_to_review_count}"
      Rails.logger.info "Proofs needing review: #{proofs_needing_review_count}"

      safe_assign(:open_applications_count, active_count)
      safe_assign(:pending_services_count, approved_count)
      safe_assign(:proofs_needing_review_count, proofs_needing_review_count)
      safe_assign(:medical_certs_to_review_count, medical_certs_to_review_count)

      # Calculate training requests count - first try notifications, then fallback to joined training sessions
      training_count = Notification.where(action: 'training_requested')
                                   .where(notifiable_type: 'Application')
                                   .select(:notifiable_id)
                                   .distinct
                                   .count

      # If no training requests found via notifications, check actual training sessions
      if training_count.zero?
        training_count = Application.joins(:training_sessions)
                                    .where(training_sessions: { status: %i[requested scheduled confirmed] })
                                    .distinct
                                    .count
      end

      safe_assign(:training_requests_count, training_count)
      Rails.logger.info "Training requests: #{training_count}"

      # Log the final instance variable values
      Rails.logger.info "Dashboard instance variables - @open_applications_count: #{@open_applications_count}, @pending_services_count: #{@pending_services_count}"
    end

    private

    # Safely assigns a value to an instance variable after sanitizing the key
    # @param key [String, Symbol] The variable name, without the '@' prefix
    # @param value [Object] The value to assign
    def safe_assign(key, value)
      # Strip leading @ if present and sanitize key to ensure valid Ruby variable name
      sanitized_key = key.to_s.sub(/\A@/, '').gsub(/[^0-9a-zA-Z_]/, '_')
      instance_variable_set("@#{sanitized_key}", value)
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
