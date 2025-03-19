class Evaluators::EvaluationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_evaluator!
  before_action :set_evaluation, except: [ :index, :new, :create, :pending, :completed ]

  def index
    if current_user.evaluator?
      # For evaluators, show only their evaluations
      @evaluations = current_user.evaluations.includes(:constituent, :application).order(created_at: :desc)
    else
      # For admins, show all evaluations
      @evaluations = Evaluation.includes(:constituent, :application, :evaluator).order(created_at: :desc)
    end
  end

  def pending
    @evaluations = current_user.evaluations.where(status: :pending)
    render :index
  end

  def completed
    @evaluations = current_user.evaluations.where(status: :completed)
    render :index
  end

  def show
    # @evaluation is set by set_evaluation
  end

  def new
    @evaluation = current_user.evaluations.build
  end

  def create
    @evaluation = current_user.evaluations.build(evaluation_params)
    @evaluation.status ||= :pending
    @evaluation.evaluation_type ||= :initial
    @evaluation.attendees ||= []
    @evaluation.products_tried ||= []
    @evaluation.recommended_product_ids ||= []

    if @evaluation.save
      redirect_to evaluators_evaluation_path(@evaluation),
        notice: "Evaluation created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # @evaluation is set by set_evaluation
  end

  def update
    if @evaluation.update(evaluation_params)
      redirect_to evaluators_evaluation_path(@evaluation), notice: "Evaluation updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def submit_report
    service = Evaluations::SubmissionService.new(@evaluation, params)

    if service.submit
      redirect_to evaluators_evaluation_path(@evaluation),
                  notice: "Evaluation submitted successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def request_additional_info
    @evaluation.request_additional_info!
    redirect_to evaluators_evaluation_path(@evaluation), notice: "Requested additional information."
  end

  private

  def set_evaluation
    # If the current user is an admin, find the evaluation directly by ID
    if current_user.admin?
      @evaluation = Evaluation.find(params[:id])
    else
      # For evaluators, find only their own evaluations
      @evaluation = current_user.evaluations.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to evaluators_evaluations_path, alert: "Evaluation not found."
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
      recommended_product_ids: []
    )
  end

  def require_evaluator!
    unless current_user&.evaluator? || current_user&.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end
end
