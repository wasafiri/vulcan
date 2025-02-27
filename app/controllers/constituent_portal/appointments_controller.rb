# app/controllers/constituent_portal/appointments_controller.rb
class ConstituentPortal::AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!
  before_action :set_appointment, only: [ :show ]

  def index
    # Get all appointments for the current user
    @appointments = current_user.appointments.order(scheduled_for: :desc)

    # Group appointments by type for the view
    @appointment_types = @appointments.group_by(&:appointment_type)
  end

  def show
  end

  private

  def set_appointment
    @appointment = current_user.appointments.find(params[:id])
  end

  def require_constituent!
    unless current_user&.constituent?
      redirect_to root_path, alert: "Access denied. Constituent-only area."
    end
  end
end
