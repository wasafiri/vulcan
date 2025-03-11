class Admin::ConstituentsDashboardController < ApplicationController
  before_action :require_admin!

  def index
    @constituents = Constituent.includes(:applications, :evaluations, :training_sessions).order(:last_name)
    @constituents = @constituents.where("last_name LIKE ?", "%#{params[:search]}%") if params[:search].present
  end

  def show
    @constituent = Constituent.find(params[:id])
    @equipment_history = @constituent.equipment_history
  end
end
