class Admin::ApplicationsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_application, only: [
    :show, :edit, :update,
    :verify_income, :request_documents, :review_proof, :update_proof_status,
    :approve, :reject, :assign_evaluator, :schedule_training, :complete_training
  ]

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
      # Default sorting
      scope = scope.order(application_date: :desc)
    end

    # Filtering by “filter” param (existing logic)
    if params[:filter].present?
      case params[:filter]
      when "proofs_needing_review"
        scope = scope.where(
          "income_proof_status = ? OR residency_proof_status = ?",
          "not_reviewed", "not_reviewed"
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

    # Additional filter by “status” param (from old Dashboard index)
    if params[:status].present?
      scope = scope.where(status: params[:status])
    end

    @pagy, @applications = pagy(scope, items: 20)
  end

  def show
  end

  def edit
  end

  def update
    if @application.update(application_params)
      redirect_to admin_application_path(@application),
                  notice: "Application updated."
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
    redirect_to admin_application_path(@application),
                notice: "Documents requested."
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

    redirect_to admin_application_path(@application),
                notice: "#{proof_type.capitalize} proof #{new_status} successfully."
  end

  # Approve a single application
  def approve
    @application.update!(status: :approved)
    redirect_to admin_application_path(@application), notice: "Application approved."
  end

  # Reject a single application
  def reject
    @application.update!(status: :rejected)
    redirect_to admin_application_path(@application), alert: "Application rejected."
  end

  # Assign an evaluator to the application
  def assign_evaluator
    evaluator = Evaluator.find(params[:evaluator_id])

    ActiveRecord::Base.transaction do
      # Create new evaluation
      evaluation = Evaluation.create!(
        evaluator: evaluator,
        constituent: @application.user,
        application: @application,
        status: :pending,
        evaluation_type: determine_evaluation_type(@application.user),
        evaluation_date: Date.current
      )

      # Send email notification
      EvaluatorMailer.with(
        evaluation: evaluation,
        constituent: @application.user
      ).new_evaluation_assigned.deliver_later
    end

    redirect_to admin_application_path(@application),
                notice: "Evaluator successfully assigned"
  end

  # Schedule training session for this application
  def schedule_training
    trainer = User.find(params[:trainer_id])
    training_session = @application.training_sessions.new(
      trainer: trainer,
      scheduled_for: params[:scheduled_for],
      status: :scheduled
    )

    if training_session.save
      redirect_to admin_application_path(@application),
                  notice: "Training session scheduled with #{trainer.full_name}"
    else
      redirect_to admin_application_path(@application),
                  alert: "Failed to schedule training session"
    end
  end

  # Mark training session as completed
  def complete_training
    training_session = @application.training_sessions.find(params[:training_session_id])
    training_session.update(status: :completed, completed_at: Time.current)

    redirect_to admin_application_path(@application),
                notice: "Training session marked as completed"
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

  def determine_evaluation_type(constituent)
    constituent.evaluations.exists? ? :follow_up : :initial
  end
end
