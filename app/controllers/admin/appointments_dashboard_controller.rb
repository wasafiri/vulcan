class Admin::AppointmentsDashboardController < ApplicationController
  before_action :require_admin!

  def index
    @appointments = Appointment.includes(:user, :evaluator)
                             .order(:scheduled_for)
                             .group_by(&:appointment_type)
  end

  def show
    @appointment = Appointment.find(params[:id])
  end
end
