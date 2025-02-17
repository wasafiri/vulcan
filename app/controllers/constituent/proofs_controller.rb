class Constituent::ProofsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!
  before_action :set_application
  before_action :ensure_can_submit_proof
  before_action :check_rate_limit, only: [ :resubmit ]

  def new
    @proof_type = params[:proof_type]
    authorize_proof_access!
  end

  def resubmit
    authorize_proof_access!

    ActiveRecord::Base.transaction do
      attach_and_update_proof
      track_submission
    end

    redirect_to constituent_application_path(@application),
      notice: "Proof submitted successfully"
  rescue RateLimit::ExceededError
    redirect_to constituent_application_path(@application),
      alert: "Please wait before submitting another proof"
  end

  private

  def set_application
    @application = current_user.applications.find(params[:application_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to constituent_dashboard_path, alert: "Application not found"
  end

  def require_constituent!
    unless current_user&.constituent?
      redirect_to root_path, alert: "Access denied"
    end
  end

  def ensure_can_submit_proof
    unless @application.can_submit_proof?
      redirect_to constituent_application_path(@application),
        alert: "Cannot submit proof at this time"
    end
  end

  def authorize_proof_access!
    unless valid_proof_type? && can_modify_proof?
      redirect_to constituent_application_path(@application),
        alert: "Invalid proof type or status"
    end
  end

  def check_rate_limit
    RateLimit.check!(:proof_submission, current_user.id)
  end

  def attach_and_update_proof
    case params[:proof_type]
    when "income"
      @application.income_proof.attach(params[:income_proof])
      @application.update!(
        income_proof_status: :not_reviewed,
        needs_review_since: Time.current
      )
    when "residency"
      @application.residency_proof.attach(params[:residency_proof])
      @application.update!(
        residency_proof_status: :not_reviewed,
        needs_review_since: Time.current
      )
    end
  end

  def track_submission
    # Create Event for application audit log
    Event.create!(
      user: current_user,
      action: "proof_submitted",
      metadata: {
        application_id: @application.id,
        proof_type: params[:proof_type]
      }
    )

    # Create ProofSubmissionAudit for policy audit log
    ProofSubmissionAudit.create!(
      application: @application,
      user: current_user,
      proof_type: params[:proof_type],
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

  def valid_proof_type?
    %w[income residency].include?(params[:proof_type])
  end

  def can_modify_proof?
    case params[:proof_type]
    when "income"
      @application.rejected_income_proof?
    when "residency"
      @application.rejected_residency_proof?
    end
  end
end
