class Constituent::ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!
  before_action :set_application, only: [ :show, :edit, :update ]

  def show
  end

  def edit
  end

  def update
    if @application.update(application_params)
      redirect_to constituent_application_path(@application), notice: "Application updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_application
    @application = current_user.applications.find(params[:id])
  end

  def application_params
    params.require(:application).permit(:status, :application_type, :household_size, :annual_income, :residency_details, :medical_provider_id)
  end

  def require_constituent!
    unless current_user&.constituent?
      redirect_to root_path, alert: "Access denied. Constituent-only area."
    end
  end
end
