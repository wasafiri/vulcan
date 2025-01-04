class Admin::ApplicationsDashboardController < ApplicationController
  before_action :require_admin!
  before_action :set_application, only: [ :show, :approve, :reject, :assign_evaluator ]

  def index
    @applications = Application.includes(:user)
      .order(status: :asc, application_date: :asc)
    @applications = @applications.where("status = ?", params[:status]) if params[:status].present?
  end

  def show
  end

  def approve
    @application.update!(status: :approved)
    redirect_to admin_applications_dashboard_path(@application), notice: "Application approved successfully."
  end

  def reject
    @application.update!(status: :rejected)
    redirect_to admin_applications_dashboard_path(@application), alert: "Application rejected."
  end

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

    redirect_to admin_applications_dashboard_path(@application),
                notice: "Evaluator successfully assigned"
  end

  private

  def set_application
    @application = Application.includes(:user, :evaluation).find(params[:id])
  end

  def determine_evaluation_type(constituent)
    constituent.evaluations.exists? ? :follow_up : :initial
  end
end
