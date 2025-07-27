# frozen_string_literal: true

module Evaluators
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_evaluator!

    def show
      # Set current filter from params or default to nil
      @current_filter = params[:filter]
      @current_status = params[:status]

      # Load data based on user type
      if current_user.admin?
        load_admin_data
      else
        load_evaluator_data
      end

      # Apply filter status if provided
      apply_filter if @current_filter.present?

      # Load display data (always needed)
      load_display_data

      # Handle different format requests appropriately
      respond_to do |format|
        format.html # renders show.html.erb as usual
        format.turbo_stream # renders show.turbo_stream.erb if it exists
      end
    end

    private

    def load_admin_data
      # For admins, show all evaluations
      @requested_evaluations = Evaluation.requested_evaluations
      @scheduled_evaluations = Evaluation.active
      @completed_evaluations = Evaluation.completed_evaluations
      @followup_evaluations = Evaluation.needing_followup
      @assigned_constituents = Constituent.where(evaluator_id: Evaluator.select(:id)).to_a.uniq(&:id)
    end

    def load_evaluator_data
      # For evaluators, show only their evaluations
      @requested_evaluations = current_user.evaluations.requested_evaluations
      @scheduled_evaluations = current_user.evaluations.active
      @completed_evaluations = current_user.evaluations.completed_evaluations
      @followup_evaluations = current_user.evaluations.needing_followup
      @assigned_constituents = current_user.assigned_constituents.to_a.uniq(&:id)
    end

    def apply_filter
      case @current_filter
      when 'requested'
        @filtered_evaluations = current_user.admin? ? Evaluation.requested_evaluations : current_user.evaluations.requested_evaluations
        @filtered_evaluations = @filtered_evaluations.order(created_at: :desc)
        @section_title = 'Requested Evaluations'
      when 'scheduled'
        @filtered_evaluations = current_user.admin? ? Evaluation.active : current_user.evaluations.active
        @filtered_evaluations = @filtered_evaluations.order(evaluation_date: :asc)
        @section_title = 'Scheduled Evaluations'
      when 'completed'
        @filtered_evaluations = current_user.admin? ? Evaluation.completed_evaluations : current_user.evaluations.completed_evaluations
        @filtered_evaluations = @filtered_evaluations.order(evaluation_date: :desc)
        @section_title = 'Completed Evaluations'
      when 'needs_followup'
        @filtered_evaluations = current_user.admin? ? Evaluation.needing_followup : current_user.evaluations.needing_followup
        @filtered_evaluations = @filtered_evaluations.order(updated_at: :desc)
        @section_title = 'Evaluations Needing Follow-up'
      end
    end

    def load_display_data
      # Always initialize these variables to empty arrays
      @requested_evaluations_display = []
      @upcoming_evaluations = []
      @recent_evaluations = []

      # If we're filtering, don't load all the display data
      return if @current_filter.present?

      # Data for dashboard tables - limit to 5 items for each section
      @requested_evaluations_display = @requested_evaluations.order(created_at: :desc).limit(5)
      @upcoming_evaluations = (current_user.admin? ? Evaluation.active : current_user.evaluations.active)
                                 .order(evaluation_date: :asc).limit(5)
      @recent_evaluations = (current_user.admin? ? Evaluation.completed_evaluations : current_user.evaluations.completed_evaluations)
                            .order(evaluation_date: :desc).limit(5)
    end

    def require_evaluator!
      return if current_user&.evaluator? || current_user&.admin?

      redirect_to root_path, alert: 'Access denied'
    end
  end
end
