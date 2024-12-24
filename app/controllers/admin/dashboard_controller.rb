class Admin::DashboardController < ApplicationController
  before_action :require_admin!

  def index
    @constituents_count = Constituent.count
    @open_applications_count = Application.where(status: :in_progress).count
    @appointments_today = Appointment.where("DATE(scheduled_for) = ?", Date.today).count
  end
end
