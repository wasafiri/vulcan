class Evaluators::EvaluationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_evaluator!
  before_action :set_evaluation, only: [ :show, :edit, :update, :submit_report, :request_additional_info, :pending, :completed ]

  def index
    @evaluations = current_user.evaluations.includes(:constituent, :application).order(created_at: :desc)
  end

  def show
    # @evaluation is set by set_evaluation
  end

  def new
    @evaluation = current_user.evaluations.build
  end

  def create
    @evaluation = current_user.evaluations.build(evaluation_params)
    @evaluation.status = :pending

    if @evaluation.save
      redirect_to evaluator_evaluation_path(@evaluation), notice: "Evaluation created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @evaluation is set by set_evaluation
  end

  def update
    if @evaluation.update(evaluation_params)
      redirect_to evaluator_evaluation_path(@evaluation), notice: "Evaluation updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def submit_report
    service = Evaluations::SubmissionService.new(@evaluation, params)
    if service.submit
      redirect_to evaluator_evaluation_path(@evaluation), notice: "Evaluation submitted successfully."
    else
      flash.now[:alert] = "Failed to submit evaluation."
      render :edit, status: :unprocessable_entity
    end
  end

  def request_additional_info
    @evaluation.request_additional_info!
    redirect_to evaluator_evaluation_path(@evaluation), notice: "Requested additional information."
  end

  def pending
    @evaluations = current_user.evaluations.pending
    render :index
  end

  def completed
    @evaluations = current_user.evaluations.completed
    render :index
  end

  private

  def set_evaluation
    @evaluation = current_user.evaluations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to evaluator_evaluations_path, alert: "Evaluation not found."
  end

  def evaluation_params
    params.require(:evaluation).permit(
      :constituent_id,
      :application_id,
      :evaluation_date,
      :evaluation_type,
      :status,
      :notes,
      :location,
      :needs,
      attendees: [ :name, :relationship ],
      products_tried: [ :product_id, :reaction ],
      recommended_product_ids: [],
      recommended_accessory_ids: []
    )
  end

  def require_evaluator!
    unless current_user.evaluator?
      redirect_to root_path, alert: "Access denied."
    end
  end
end
