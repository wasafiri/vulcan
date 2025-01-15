class Admin::ApplicationsController < ApplicationController
  include Pagy::Backend
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_application, only: [ :show, :edit, :update, :verify_income, :request_documents, :review_proof, :update_proof_status ]

  def index
    # Base query with includes
    scope = Application.includes(:user)

    # Sorting if present
    if params[:sort].present?
      sort_column = params[:sort]
      sort_direction = params[:direction] || "asc"
      if Application.column_names.include?(sort_column)
        scope = scope.order("#{sort_column} #{sort_direction}")
      end
    else
      scope = scope.order(application_date: :desc)
    end

    # Filtering
    if params[:filter].present?
      case params[:filter]
      when "proofs_needing_review"
        scope = scope.where(
          "income_proof_status = ? OR residency_proof_status = ?",
          "not_reviewed",
          "not_reviewed"
        )
      when "proofs_rejected"
        scope = scope.where(
          income_proof_status: :rejected,
          residency_proof_status: :rejected
        )
      when "awaiting_medical_response"
        scope = scope.where(status: :awaiting_documents)
      end
    end
    @pagy, @applications = pagy(scope, items: 20)
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

  def request_documents
    @application.update!(status: :awaiting_documents)
    redirect_to admin_application_path(@application), notice: "Documents requested."
  end

  def review_proof
    respond_to do |format|
      format.js
    end
  end

  def update_proof_status
    proof_type = params[:proof_type]
    new_status = params[:status]

    case proof_type
    when "income"
      @application.update(income_proof_status: new_status)
    when "residency"
      @application.update(residency_proof_status: new_status)
    else
      render json: { error: "Invalid proof type" }, status: :unprocessable_entity
      return
    end

    redirect_to admin_application_path(@application), notice: "#{proof_type.capitalize} proof #{new_status} successfully."
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
