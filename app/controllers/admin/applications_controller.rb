class Admin::ApplicationsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_current_attributes
  before_action :set_application, only: [
    :show, :edit, :update,
    :verify_income, :request_documents, :review_proof, :update_proof_status,
    :approve, :reject, :assign_evaluator, :schedule_training, :complete_training,
    :update_certification_status
  ]

  def index
    @current_fiscal_year = fiscal_year
    @total_users_count = User.count
    @ytd_constituents_count = Application.where("created_at >= ?", fiscal_year_start).count
    @open_applications_count = Application.active.count
    @pending_services_count = Application.where(status: :approved).count

    # Get base scope with includes
    scope = Application.includes(:user, :income_proof_attachment, :residency_proof_attachment)
      .where.not(status: [ :rejected, :archived ])

    # Apply filters
    scope = case params[:filter]
    when "in_progress"
      scope.where(status: :in_progress)
    when "approved"
      scope.where(status: :approved)
    when "proofs_needing_review"
      scope.where(income_proof_status: 0)
           .or(scope.where(residency_proof_status: 0))
    when "awaiting_medical_response"
      scope.where(status: :awaiting_documents)
    else
      scope
    end

    @pagy, @applications = pagy(scope, items: 20)
  end

  def show
    # Eager load attachments to prevent N+1 queries
    @application.documents.attachments.load
    @application.income_proof.attachments.load
    @application.residency_proof.attachments.load
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
    @applications = Application.search_by_last_name(params[:q])
  end

  def filter
    @applications = Application.includes(:user).where(status: params[:status])
  end

  def batch_approve
    Application.batch_update_status(params[:ids], :approved)
    redirect_to admin_applications_path, notice: "Applications approved."
  end

  def batch_reject
    Application.batch_update_status(params[:ids], :rejected)
    redirect_to admin_applications_path, notice: "Applications rejected."
  end

  def request_documents
    @application.request_documents!
    redirect_to admin_application_path(@application), notice: "Documents requested."
  end

  def review_proof
    respond_to do |format|
      format.js
    end
  end

  def update_proof_status
    if @application.update_proof_status!(params[:proof_type], params[:status])
      redirect_to admin_application_path(@application),
        notice: "#{params[:proof_type].capitalize} proof #{params[:status]} successfully."
    else
      render json: { error: "Invalid proof type" }, status: :unprocessable_entity
    end
  end

  def approve
    if @application.approve!
      flash[:notice] = "Application approved."
      redirect_to admin_application_path(@application)
    else
      flash[:alert] = "Failed to approve Application ##{@application.id}: #{@application.errors.full_messages.to_sentence}"
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "Failed to approve Application ##{@application.id}: #{e.record.errors.full_messages.to_sentence}"
    render :show, status: :unprocessable_entity
  end

  def reject
    if @application.reject!
      flash[:alert] = "Application rejected."
      redirect_to admin_application_path(@application)
    else
      flash[:alert] = "Failed to reject Application ##{@application.id}: #{@application.errors.full_messages.to_sentence}"
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "Failed to reject Application ##{@application.id}: #{e.record.errors.full_messages.to_sentence}"
    render :show, status: :unprocessable_entity
  end

  def assign_evaluator
    evaluator = Evaluator.find(params[:evaluator_id])

    if @application.assign_evaluator!(evaluator)
      redirect_to admin_application_path(@application),
        notice: "Evaluator successfully assigned"
    else
      redirect_to admin_application_path(@application),
        alert: "Failed to assign evaluator"
    end
  end

  def schedule_training
    trainer = Trainer.active.find_by(id: params[:trainer_id])
    unless trainer
      redirect_to admin_application_path(@application), alert: "Invalid trainer selected."
      return
    end

    training_session = @application.schedule_training!(
      trainer: trainer,
      scheduled_for: params[:scheduled_for]
    )

    if training_session.persisted?
      redirect_to admin_application_path(@application),
        notice: "Training session scheduled with #{trainer.full_name}"
    else
      redirect_to admin_application_path(@application),
        alert: "Failed to schedule training session"
    end
  end

  def complete_training
    training_session = @application.training_sessions.find(params[:training_session_id])
    training_session.complete!

    redirect_to admin_application_path(@application),
      notice: "Training session marked as completed"
  end

  def update_certification_status
    if @application.update_certification!(
        certification: params[:medical_certification],
        status: params[:status],
        verified_by: current_user
      )
      redirect_to admin_application_path(@application),
        notice: "Medical certification status updated."
    else
      redirect_to admin_application_path(@application),
        alert: "Failed to update certification status."
    end
  end

  private

  def sort_column
    params[:sort] || "application_date"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end

  def filter_conditions
    # Define your filter conditions based on params[:filter]
    case params[:filter]
    when "in_progress"
      { status: "in_progress" }
    when "approved"
      { status: "approved" }
    when "proofs_needing_review"
      { status: "proofs_needing_review" }
    when "awaiting_medical_response"
      { status: "awaiting_medical_response" }
    else
      {}
    end
  end

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

  private

  def set_current_attributes
    Current.set(request, current_user)
  end

  def fiscal_year
    current_date = Date.current
    current_date.month >= 7 ? current_date.year : current_date.year - 1
  end

  def fiscal_year_start
    year = fiscal_year
    Date.new(year, 7, 1)
  end
end
