class Constituent::ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!
  before_action :set_application, only: [ :show, :edit, :update ]

  def new
    @application = current_user.applications.new
  end

  def create
    @application = current_user.applications.new(application_params)
    @application.application_date = Time.current
    @application.status = :in_progress

    ActiveRecord::Base.transaction do
      if current_user.update(disability_params) && @application.save
        redirect_to constituent_application_path(@application), notice: "Application submitted successfully."
      else
        @application.errors.merge!(current_user.errors)
        render :new, status: :unprocessable_entity
      end
    end
  end

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
    params.require(:application).permit(
      :household_size,
      :annual_income,
      :residency_details,
      :self_certify_disability,
      :medical_provider_id
    )
  end

  def disability_params
    params.require(:application).permit(
      :is_guardian,
      :guardian_relationship,
      :residency_proof,
      :income_proof,
      :hearing_disability,
      :vision_disability,
      :speech_disability,
      :mobility_disability,
      :cognition_disability
    )
  end

  def require_constituent!
    unless current_user&.constituent?
      redirect_to root_path, alert: "Access denied. Constituent-only area."
    end
  end
end
