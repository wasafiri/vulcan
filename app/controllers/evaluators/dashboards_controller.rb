class Evaluator::DashboardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_evaluator!

  def show
    # Fetch evaluator-specific dashboard data
    @evaluations = current_user.evaluations
    # Add other necessary instance variables
  end

  private

  def require_evaluator!
    unless current_user&.evaluator?
      redirect_to root_path, alert: "Access denied"
    end
  end
end
