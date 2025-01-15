class Constituent::DashboardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!

  def show
    # Draft application check
    @draft_application = current_user.applications.draft.first

    # Active application check (non-draft)"
    @active_application = current_user.applications.where.not(status: "draft").order(created_at: :desc).first

    # Upcoming appointments
    @upcoming_appointments_count = current_user.appointments.where("scheduled_for > ?", Time.current).count

    # Devices count - use 0 if no devices method exists
    @devices_count = 0

    # Recent activities - use empty array if no activities method exists
    @recent_activities = []
  end

  private

  def require_constituent!
    unless current_user&.constituent?
      redirect_to root_path, alert: "Access denied. Constituent-only area."
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
                  .where("scheduled_for > ?", Time.current)
                  .order(scheduled_for: :asc)
                  .limit(3)
    )

    # Sort combined activities by date
    activities.sort_by(&:created_at).reverse.first(5)
  end
end
