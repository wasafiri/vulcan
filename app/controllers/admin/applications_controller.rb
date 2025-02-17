class Admin::ApplicationsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_current_attributes
  before_action :set_application, only: [
    :show, :edit, :update,
    :verify_income, :request_documents, :review_proof, :update_proof_status,
    :approve, :reject, :assign_evaluator, :schedule_training, :complete_training,
    :update_certification_status, :resend_medical_certification
  ]

  def index
    @current_fiscal_year = fiscal_year
    @total_users_count = User.count
    @ytd_constituents_count = Application.where("created_at >= ?", fiscal_year_start).count
    @open_applications_count = Application.active.count
    @pending_services_count = Application.where(status: :approved).count

    # Get base scope with includes
    scope = Application.includes(:user)
      .with_attached_income_proof
      .with_attached_residency_proof
      .where.not(status: [ :rejected, :archived ])

    scope = apply_filters(scope, params[:filter])

    @pagy, @applications = pagy(scope, items: 20)
  end

  def show
    @application = Application.includes(
      :user,
      :evaluations,
      :training_sessions
    ).find(params[:id])

    # Fetch all audit logs and combine them
    proof_reviews = @application.proof_reviews.includes(admin: :role_capabilities).order(created_at: :desc)
    status_changes = @application.status_changes.includes(user: :role_capabilities).order(created_at: :desc)
    notifications = Notification.includes(actor: :role_capabilities)
      .where(notifiable: @application)
      .where(
      action: %w[
        medical_certification_requested
        medical_certification_received
        medical_certification_approved
        medical_certification_rejected
        review_requested
        documents_requested
        proof_approved
        proof_rejected
      ]
    ).order(created_at: :desc)

    @audit_logs = (proof_reviews + status_changes + notifications)
      .sort_by(&:created_at)
      .reverse
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
    result = Application.batch_update_status(params[:ids], :approved)
    if result
      redirect_to admin_applications_path, notice: "Applications approved."
    else
      render json: { error: "Unable to approve applications" },
        status: :unprocessable_entity
    end
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
    reviewer = Applications::ProofReviewer.new(@application, current_user)
    begin
      Rails.logger.info "Starting proof review in controller"
      Rails.logger.info "Parameters: proof_type=#{params[:proof_type]}, status=#{params[:status]}"

      reviewer.review(
        proof_type: params[:proof_type],
        status: params[:status],
        rejection_reason: params[:rejection_reason]
      )

      Rails.logger.info "Proof review completed successfully"

      respond_to do |format|
        format.html {
          flash[:notice] = "#{params[:proof_type].capitalize} proof #{params[:status]} successfully."
          redirect_to admin_application_path(@application)
        }
        format.turbo_stream {
          # Reload application and fetch audit logs
          @application = Application.includes(
            :user,
            :evaluations,
            :training_sessions
          ).find(params[:id])

          proof_reviews = @application.proof_reviews.includes(admin: :role_capabilities).order(created_at: :desc)
          status_changes = @application.status_changes.includes(user: :role_capabilities).order(created_at: :desc)
          notifications = Notification.includes(actor: :role_capabilities)
            .where(notifiable: @application)
            .where(
            action: %w[
              medical_certification_requested
              medical_certification_received
              medical_certification_approved
              medical_certification_rejected
              review_requested
              documents_requested
              proof_approved
              proof_rejected
            ]
          ).order(created_at: :desc)

          @audit_logs = (proof_reviews + status_changes + notifications)
            .sort_by(&:created_at)
            .reverse

          flash.now[:notice] = "#{params[:proof_type].capitalize} proof #{params[:status]} successfully."
          # First remove all modals
          streams = [
            turbo_stream.remove("proofRejectionModal"),
            turbo_stream.remove("incomeProofReviewModal"),
            turbo_stream.remove("residencyProofReviewModal"),
            turbo_stream.remove("medicalCertificationReviewModal")
          ]

          # Then update content
          streams.concat([
            turbo_stream.update("flash", partial: "shared/flash"),
            turbo_stream.update("attachments-section", partial: "attachments"),
            turbo_stream.update("audit-logs", partial: "audit_logs"),
            turbo_stream.update("modals", partial: "modals")
          ])

          render turbo_stream: streams
        }
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update proof status: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      respond_to do |format|
        format.html {
          flash[:error] = "Failed to update proof status: #{e.message}"
          render :show, status: :unprocessable_entity
        }
        format.turbo_stream {
          flash.now[:error] = "Failed to update proof status: #{e.message}"
          render turbo_stream: turbo_stream.update("flash", partial: "shared/flash")
        }
      end
    end
  end

  def process_application_status(action)
    past_tense = { "approve" => "approved", "reject" => "rejected" }
    if @application.send("#{action}!")
      flash[:notice] = "Application #{past_tense[action.to_s]}."
      redirect_to admin_application_path(@application)
    else
      flash[:alert] = "Failed to #{action} Application ##{@application.id}: #{@application.errors.full_messages.to_sentence}"
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "Failed to #{action} Application ##{@application.id}: #{e.record.errors.full_messages.to_sentence}"
    render :show, status: :unprocessable_entity
  end

  def approve
    process_application_status(:approve)
  end

  def reject
    process_application_status(:reject)
  end

  def assign_evaluator
    @application = Application.find(params[:id])
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
        verified_by: current_user,
        rejection_reason: params[:rejection_reason]
      )
      redirect_to admin_application_path(@application),
        notice: "Medical certification status updated."
    else
      redirect_to admin_application_path(@application),
        alert: "Failed to update certification status."
    end
  end

  def resend_medical_certification
    # Send the certification request email
    MedicalProviderMailer.request_certification(@application).deliver_now

    # Update the certification requested date and increment the count
    @application.transaction do
      @application.update!(medical_certification_requested_at: Time.current)
      @application.increment!(:medical_certification_request_count)
    end

    redirect_to admin_application_path(@application), notice: "Certification request resent."
  end

  private

  def apply_filters(scope, filter)
    case filter
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
  end

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
      { status: :in_progress }
    when "approved"
      { status: :approved }
    when "proofs_needing_review"
      { status: :proofs_needing_review }
    when "awaiting_medical_response"
      { status: :awaiting_medical_response }
    else
      {}
    end
  end

  def set_application
    @application = Application.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_applications_path, alert: "Application not found"
  end

  def application_params
    params.require(:application).permit(
      :status,
      :household_size,
      :annual_income,
      :application_type,
      :submission_method,
      :medical_provider_name,
      :medical_provider_phone,
      :medical_provider_fax,
      :medical_provider_email
    )
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end

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
