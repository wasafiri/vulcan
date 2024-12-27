module Evaluator
  class EvaluationsController < ApplicationController
    # Ensure the user is an evaluator before accessing any actions
    before_action :require_evaluator!
    # Set the evaluation instance for specific actions
    before_action :set_evaluation, only: [ :show, :edit, :update, :submit_report, :request_additional_info, :pending, :completed ]

    # GET /evaluator/evaluations
    def index
      @evaluations = current_user.evaluations
    end

    # GET /evaluator/evaluations/:id
    def show
      # @evaluation is set by set_evaluation
    end

    # GET /evaluator/evaluations/new
    def new
      @evaluation = current_user.evaluations.build
    end

    # POST /evaluator/evaluations
    def create
      @evaluation = current_user.evaluations.build(evaluation_params)
      if @evaluation.save
        redirect_to evaluator_evaluation_path(@evaluation), notice: "Evaluation was successfully created."
      else
        render :new
      end
    end

    # GET /evaluator/evaluations/:id/edit
    def edit
      # @evaluation is set by set_evaluation
    end

    # PATCH/PUT /evaluator/evaluations/:id
    def update
      if @evaluation.update(evaluation_params)
        redirect_to evaluator_evaluation_path(@evaluation), notice: "Evaluation was successfully updated."
      else
        render :edit
      end
    end

    # POST /evaluator/evaluations/:id/submit_report
    def submit_report
      if @evaluation.update(report_submitted: true)
        redirect_to evaluator_evaluation_path(@evaluation), notice: "Report submitted successfully."
      else
        redirect_back fallback_location: evaluator_evaluations_path, alert: "Failed to submit report."
      end
    end

    # POST /evaluator/evaluations/:id/request_additional_info
    def request_additional_info
      @evaluation.request_additional_info!
      redirect_to evaluator_evaluation_path(@evaluation), notice: "Requested additional information."
    end

    # GET /evaluator/evaluations/pending
    def pending
      @evaluations = current_user.evaluations.pending
      render :index
    end

    # GET /evaluator/evaluations/completed
    def completed
      @evaluations = current_user.evaluations.completed
      render :index
    end

    private

    # Set the @evaluation instance variable based on the provided ID
    def set_evaluation
      @evaluation = current_user.evaluations.find(params[:id])
    end

    # Strong parameters for evaluation
    def evaluation_params
      params.require(:evaluation).permit(:constituent_id, :evaluation_date, :evaluation_type, :notes)
    end
  end
end
