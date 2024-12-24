# app/controllers/constituent/dashboard_controller.rb
module Constituent
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_constituent!

    def show
      @upcoming_appointments_count = current_user.appointments
                                               .where('scheduled_for > ?', Time.current)
                                               .count
      
      @devices_count = current_user.applications
                                 .where(status: :approved)
                                 .count
                                 
      @recent_activities = recent_activities
    end

    private

    def require_constituent!
      unless current_user&.constituent?
        redirect_to root_path, alert: 'Access denied. Constituent-only area.'
      end
    end

    def recent_activities
      # Combine recent notifications, application updates, and appointments
      activities = []
      
      # Get recent notifications
      activities.concat(
        current_user.received_notifications
                   .includes(:actor)
                   .order(created_at: :desc)
                   .limit(5)
      )
      
      # Get recent appointments
      activities.concat(
        current_user.appointments
                   .includes(:evaluator)
                   .where('scheduled_for > ?', Time.current)
                   .order(scheduled_for: :asc)
                   .limit(3)
      )
      
      # Sort combined activities by date
      activities.sort_by(&:created_at).reverse.first(5)
    end
  end
end
