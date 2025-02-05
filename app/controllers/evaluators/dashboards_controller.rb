module Evaluators
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_evaluator!

    def show
      @pending_evaluations = current_user.evaluations.pending
      @completed_evaluations = current_user.evaluations.completed
      @assigned_constituents = current_user.assigned_constituents.to_a.uniq { |c| c.id }
    end

    private

    def require_evaluator!
      unless current_user&.evaluator? || current_user&.admin?
        redirect_to root_path, alert: "Access denied"
      end
    end
  end
end
