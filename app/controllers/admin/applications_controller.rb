class Admin::ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_application, only: [ :show, :edit, :update, :verify_income, :request_documents ]

  def index
    @applications = Application.includes(:user).all
  end

  def show
  end

  def edit
  end

  def update
    if @application.update(application_params)
      redirect_to admin_application_path(@application), notice: "Application updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def search
    @applications = Application.includes(:user)
      .where("users.last_name ILIKE ?", "%#{params[:q]}%")
      .references(:users)
  end

  def filter
    @applications = Application.includes(:user).where(status: params[:status])
  end

  def batch_approve
    Application.where(id: params[:ids]).update_all(status: :approved)
    redirect_to admin_applications_path, notice: "Applications approved."
  end

  def batch_reject
    Application.where(id: params[:ids]).update_all(status: :rejected)
    redirect_to admin_applications_path, notice: "Applications rejected."
  end

  def verify_income
    @application.update!(income_verification_status: :verified)
    redirect_to admin_application_path(@application), notice: "Income verified."
  end

  def request_documents
    @application.update!(status: :awaiting_documents)
    redirect_to admin_application_path(@application), notice: "Documents requested."
  end

  private

  def set_application
    @application = Application.find(params[:id])
  end

  def application_params
    params.require(:application).permit(:status, :household_size, :annual_income)
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end
end
