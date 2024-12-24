class Admin::ConstituentsDashboardController < ApplicationController
  before_action :require_admin!

  def index
    @constituents = Constituent.includes(:applications, :appointments).order(:last_name)
    @constituents = @constituents.where("last_name LIKE ?", "%#{params[:search]}%") if params[:search].present
  end

  def show
    @constituent = Constituent.find(params[:id])
    @appointments = @constituent.appointments.order(:scheduled_for)
    @equipment_history = @constituent.equipment_history
  end
end
