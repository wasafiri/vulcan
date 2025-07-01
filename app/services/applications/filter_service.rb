# frozen_string_literal: true

module Applications
  class FilterService < BaseService
    attr_reader :scope, :params

    def initialize(scope, params = {})
      super()
      @scope = scope
      @params = params
    end

    # Apply filters based on the provided parameters
    def apply_filters
      result = scope

      # Apply filter from params[:filter]
      result = apply_status_filter(result, params[:filter]) if params[:filter].present?

      # Apply explicit status filter
      result = result.where(status: params[:status]) if params[:status].present?

      # Apply date range filter
      result = apply_date_range_filter(result) if params[:date_range].present?

      # Apply search filter
      result = apply_search_filter(result) if params[:q].present?

      # Apply guardian relationship filters
      result = apply_guardian_relationship_filters(result)

      # Return success result with the filtered scope
      # Use positional parameters to match the BaseService method definition
      success(nil, result)
    rescue StandardError => e
      Rails.logger.error "Error applying filters: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Return the original scope in the data field on failure, along with an error message.
      # Use positional parameters to match the BaseService method definition
      failure("Error applying filters: #{e.message}", scope)
    end

    private

    def apply_status_filter(scope, filter)
      case filter
      when 'active'
        scope.active
      when 'in_progress'
        scope.where(status: :in_progress)
      when 'approved'
        scope.where(status: :approved)
      when 'rejected'
        scope.where(status: :rejected)
      when 'proofs_needing_review'
        # Use Rails enum mapping to get the correct integer values
        scope.where(income_proof_status: :not_reviewed).or(scope.where(residency_proof_status: :not_reviewed))
      when 'awaiting_medical_response'
        scope.where(status: :awaiting_documents)
      when 'medical_certs_to_review'
        # Only include applications that are in progress and have received certs
        scope.where(status: :in_progress, medical_certification_status: :received)
      when 'training_requests'
        # Match the controller logic: check notifications first, then fall back to training sessions
        notification_app_ids = Notification.where(action: 'training_requested')
                                           .where(notifiable_type: 'Application')
                                           .select(:notifiable_id)
                                           .distinct
                                           .pluck(:notifiable_id)

        if notification_app_ids.any?
          scope.where(id: notification_app_ids)
        else
          # Fall back to training sessions if no notifications
          scope.with_pending_training
        end
      when 'dependent_applications'
        # Filter applications that are for dependents (have a managing_guardian)
        scope.where.not(managing_guardian_id: nil)
      else
        scope
      end
    end

    def apply_date_range_filter(scope)
      case params[:date_range]
      when 'current_fy'
        fy = fiscal_year
        date_range = Date.new(fy, 7, 1)..Date.new(fy + 1, 6, 30)
        scope.where(created_at: date_range)
      when 'previous_fy'
        fy = fiscal_year - 1
        date_range = Date.new(fy, 7, 1)..Date.new(fy + 1, 6, 30)
        scope.where(created_at: date_range)
      when 'last_30'
        scope.where(created_at: 30.days.ago.beginning_of_day..)
      when 'last_90'
        scope.where(created_at: 90.days.ago.beginning_of_day..)
      else
        scope
      end
    end

    def apply_search_filter(scope)
      search_term = "%#{params[:q]}%"
      # Join with users table to search on user fields in a single query
      scope.joins(:user).where(
        'applications.id::text ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ?',
        search_term, search_term, search_term, search_term
      )
    end

    def apply_guardian_relationship_filters(scope)
      result = scope

      # Filter by managing guardian
      result = result.where(managing_guardian_id: params[:managing_guardian_id]) if params[:managing_guardian_id].present?

      # Filter by applications for dependents of a specific guardian
      if params[:guardian_id].present?
        # Use the scope defined in the Application model
        guardian = User.find_by(id: params[:guardian_id])
        result = result.for_dependents_of(guardian) if guardian.present?
      end

      # Filter by applications for a specific dependent
      result = result.where(user_id: params[:dependent_id]) if params[:dependent_id].present?

      # Filter to show only applications for dependents
      result = result.where.not(managing_guardian_id: nil) if params[:only_dependent_apps] == 'true'

      # Always return a relation, even if filters didn't match anything
      result || Application.none
    end

    def fiscal_year
      current_date = Date.current
      current_date.month >= 7 ? current_date.year : current_date.year - 1
    end
  end
end
