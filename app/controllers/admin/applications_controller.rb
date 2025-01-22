class Admin::ApplicationsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_application, only: [
    :show, :edit, :update,
    :verify_income, :request_documents, :review_proof, :update_proof_status,
    :approve, :reject, :assign_evaluator, :schedule_training, :complete_training,
    :update_certification_status
  ]

  def index
    scope = Application.includes(:user)
                      .filter_by_status(params[:status])
                      .filter_by_type(params[:filter])
                      .sorted_by(params[:sort], params[:direction])

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
    @application.approve!
    redirect_to admin_application_path(@application), notice: "Application approved."
  end

  def reject
    @application.reject!
    redirect_to admin_application_path(@application), alert: "Application rejected."
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
    trainer = User.find(params[:trainer_id])
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
