# app/controllers/evaluators/dashboards_controller.rb
module Evaluators
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_evaluator!

    def show
      @evaluations = current_user.evaluations
    end

    private

    def require_evaluator!
      unless current_user&.evaluator?
        redirect_to root_path, alert: "Access denied"
      end
    end
  end
end
