# frozen_string_literal: true

module Admin
  # Controller for displaying application analytics, such as pain points.
  class ApplicationAnalyticsController < Admin::BaseController
    # GET /admin/application_analytics/pain_points
    def pain_points
      safe_assign(:analysis_results, Application.pain_point_analysis)
      # The view will handle displaying @analysis_results
    end
  end
end
