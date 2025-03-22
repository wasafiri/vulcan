class Evaluators::EvaluationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_evaluator!
  before_action :set_evaluation, except: [ :index, :new, :create, :pending, :completed, :requested, :scheduled, :needs_followup, :filter ]

  def index
    # Redirect to dashboard for main entry point
    # If specific filters are applied, still show the filtered list
    if params[:status].present? || params[:scope].present? || params[:filter].present?
      if current_user.evaluator?
        # For evaluators, show only their evaluations
        @evaluations = current_user.evaluations.includes(:constituent, :application).order(created_at: :desc)
      else
        # For admins, show all evaluations
        @evaluations = Evaluation.includes(:constituent, :application, :evaluator).order(created_at: :desc)
      end
    else
      redirect_to evaluators_dashboard_path
    end
  end

  # New filter action to handle combined scope + status filtering
  def filter
    scope_param = params[:scope] || (current_user.admin? ? 'all' : 'mine')
    status_param = params[:status]

    # Apply filters
    @evaluations = filter_evaluations(scope_param, status_param)

    # Set current selections for UI state
    @current_scope = scope_param
    @current_status = status_param

    render :index
  end

  def requested
    if current_user.admin?
      @evaluations = Evaluation.where(status: :requested)
                             .includes(:constituent, :application)
                             .order(created_at: :desc)
    else
      @evaluations = current_user.evaluations.requested_evaluations
                              .includes(:constituent, :application)
                              .order(created_at: :desc)
    end
    render :index
  end

  def scheduled
    if current_user.admin?
      @evaluations = Evaluation.where(status: [:scheduled, :confirmed])
                             .includes(:constituent, :application)
                             .order(evaluation_datetime: :asc)
    else
      @evaluations = current_user.evaluations.active
                              .includes(:constituent, :application)
                              .order(evaluation_datetime: :asc)
    end
    render :index
  end

  def pending
    @evaluations = current_user.evaluations.pending
                            .includes(:constituent, :application)
                            .order(created_at: :desc)
    render :index
  end

  def completed
    @evaluations = current_user.evaluations.completed_evaluations
                            .includes(:constituent, :application)
                            .order(evaluation_date: :desc)
    render :index
  end

  def needs_followup
    if current_user.admin?
      @evaluations = Evaluation.where(status: [:no_show, :cancelled])
                             .includes(:constituent, :application)
                             .order(updated_at: :desc)
    else
      @evaluations = current_user.evaluations.needing_followup
                              .includes(:constituent, :application)
                              .order(updated_at: :desc)
    end
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
    # Process attendees from the attendees_field
    if params[:evaluation][:attendees_field].present?
      attendees = params[:evaluation][:attendees_field].split(',').map do |attendee_str|
        name, relationship = attendee_str.strip.split('-').map(&:strip)
        { 'name' => name, 'relationship' => relationship }
      end
      params[:evaluation][:attendees] = attendees
    end
    
    # Process products tried from multi-select
    if params[:evaluation][:products_tried_field].present?
      products_tried = params[:evaluation][:products_tried_field].map do |product_id|
        { 'product_id' => product_id, 'reaction' => 'Recorded during evaluation' }
      end
      params[:evaluation][:products_tried] = products_tried
    end
    
    if @evaluation.update(evaluation_params)
      redirect_to evaluators_evaluation_path(@evaluation), notice: "Evaluation updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def schedule
    @evaluation.evaluation_datetime = params[:evaluation_datetime]
    @evaluation.location = params[:location]
    @evaluation.notes = params[:notes]
    @evaluation.status = :scheduled
    
    if @evaluation.save
      redirect_to evaluators_evaluation_path(@evaluation), notice: "Evaluation scheduled successfully."
    else
      redirect_to evaluators_evaluation_path(@evaluation), alert: @evaluation.errors.full_messages.join(", ")
    end
  end
  
  def reschedule
    @evaluation.evaluation_datetime = params[:evaluation_datetime]
    @evaluation.location = params[:location] if params[:location].present?
    @evaluation.reschedule_reason = params[:reschedule_reason]
    @evaluation.status = :scheduled # Reset to scheduled status
    
    if @evaluation.save
      redirect_to evaluators_evaluation_path(@evaluation), notice: "Evaluation rescheduled successfully."
    else
      redirect_to evaluators_evaluation_path(@evaluation), alert: @evaluation.errors.full_messages.join(", ")
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
      :evaluation_datetime,
      :evaluation_type,
      :status,
      :notes,
      :location,
      :needs,
      :reschedule_reason,
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

  def filter_evaluations(scope, status)
    # Base query - either all sessions or just mine
    if scope == "all" && current_user.admin?
      base_query = Evaluation.all
    else
      base_query = current_user.evaluations
    end

    # Apply status filter if provided
    filtered_query = if status.present?
                       base_query.where(status: status)
                     else
                       base_query
                     end

    # Apply appropriate order based on status
    ordered_query = case status
                    when "completed"
                      filtered_query.order(evaluation_date: :desc)
                    when "scheduled", "confirmed"
                      filtered_query.order(evaluation_datetime: :asc)
                    when "requested"
                      filtered_query.order(created_at: :desc)
                    when "no_show", "cancelled"
                      filtered_query.order(updated_at: :desc)
                    else
                      # Default order
                      filtered_query.order(updated_at: :desc)
                    end

    # Include associated models for performance
    ordered_query.includes(:constituent, :application)
  end
end
