class Admin::ApplicationsDashboardController < ApplicationController
  before_action :require_admin!

  def index
    @applications = Application.includes(:user)
                                .order(status: :asc, application_date: :asc)
    @applications = @applications.where("status = ?", params[:status]) if params[:status].present?
  end

  def show
    @application = Application.find(params[:id])
  end
end
