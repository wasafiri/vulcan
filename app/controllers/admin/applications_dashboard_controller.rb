class Admin::ApplicationsDashboardController < ApplicationController
  before_action :require_admin!

  def index
    @applications = Application.includes(:user)
                                .order(status: :asc, application_date: :asc)
    @applications = @applications.where("status = ?", params[:status]) if params[:status].present?
  end

  def show
    @application = Application.includes(:user).find(params[:id])
  end

  def approve
    @application.update!(status: :approved)
    redirect_to admin_applications_dashboard_path(@application), notice: "Application approved successfully."
  end

  def reject
    @application.update!(status: :rejected)
    redirect_to admin_applications_dashboard_path(@application), alert: "Application rejected."
  end
end
