# app/controllers/constituent/appointments_controller.rb
class Constituent::AppointmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!
  before_action :set_appointment, only: [ :show ]

  def index
    @appointments = current_user.appointments.order(scheduled_for: :desc)
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
