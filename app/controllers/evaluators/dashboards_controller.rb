module Evaluators
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_evaluator!

    def show
      # Summary card data
      if current_user.admin?
        # For admins, show all evaluations
        @requested_evaluations = Evaluation.requested_evaluations
        @scheduled_evaluations = Evaluation.active
        @completed_evaluations = Evaluation.completed_evaluations
        @followup_evaluations = Evaluation.needing_followup
        
        # Data for dashboard tables
        @requested_evaluations_display = @requested_evaluations.order(created_at: :desc).limit(5)
        @upcoming_evaluations = Evaluation.active.order(evaluation_datetime: :asc).limit(5)
        @recent_evaluations = Evaluation.completed_evaluations.order(evaluation_date: :desc).limit(5)
        
        @assigned_constituents = Constituent.where(evaluator_id: Evaluator.pluck(:id)).to_a.uniq(&:id)
      else
        # For evaluators, show only their evaluations
        @requested_evaluations = current_user.evaluations.requested_evaluations
        @scheduled_evaluations = current_user.evaluations.active
        @completed_evaluations = current_user.evaluations.completed_evaluations
        @followup_evaluations = current_user.evaluations.needing_followup
        
        # Data for dashboard tables
        @requested_evaluations_display = @requested_evaluations.order(created_at: :desc).limit(5)
        @upcoming_evaluations = current_user.evaluations.active.order(evaluation_datetime: :asc).limit(5)
        @recent_evaluations = current_user.evaluations.completed_evaluations.order(evaluation_date: :desc).limit(5)
        
        @assigned_constituents = current_user.assigned_constituents.to_a.uniq(&:id)
      end
    end

    private

    def require_evaluator!
      return if current_user&.evaluator? || current_user&.admin?

      redirect_to root_path, alert: 'Access denied'
    end
  end
end
