module Evaluator
  class DashboardController < ApplicationController
    before_action :require_evaluator!

    def show
      # Fetch evaluator-specific dashboard data
      @evaluations = current_user.evaluations
      # Add other necessary instance variables
    end
  end
end
