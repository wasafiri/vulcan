class Admin::ApplicationsController < Admin::BaseController
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::JavaScriptHelper
  before_action :set_application, only: [
    :show, :edit, :update,
    :verify_income, :request_documents, :review_proof, :update_proof_status,
    :approve, :reject, :assign_evaluator, :assign_trainer, :schedule_training, :complete_training,
    :update_certification_status, :resend_medical_certification, :assign_voucher
  ]
  before_action :load_audit_logs, only: [:show, :approve, :reject]

  def index
    @current_fiscal_year = fiscal_year
    @total_users_count = User.count
    @ytd_constituents_count = Application.where("created_at >= ?", fiscal_year_start).count
    @open_applications_count = Application.active.count
    @pending_services_count = Application.where(status: :approved).count
    
    # Load recent notifications for the notifications section
    @recent_notifications = Notification.includes(:actor, :notifiable)
                                       .order(created_at: :desc)
                                       .limit(5)

    # Data for Common Tasks section
    income_proofs_pending = Application.joins(:income_proof_attachment)
                                       .where(income_proof_status: "not_reviewed")
    residency_proofs_pending = Application.joins(:residency_proof_attachment)
                                          .where(residency_proof_status: "not_reviewed")
    @proofs_needing_review_count = (income_proofs_pending.pluck(:id) + residency_proofs_pending.pluck(:id)).uniq.count

    @medical_certs_to_review_count = Application.where(medical_certification_status: "received").count

    # Count applications with pending training sessions - include admin as trainer
    @training_requests_count = Application.joins(:training_sessions)
      .where(training_sessions: { status: [:requested, :scheduled, :confirmed] })
      .distinct.count

    # Application Pipeline data for funnel chart
    @draft_count = Application.where(status: "draft").count
    @submitted_count = Application.where.not(status: "draft").count
    @in_review_count = Application.where(status: [ "submitted", "in_review" ]).count
    @approved_count = Application.where(status: "approved").count

    @pipeline_chart_data = {
      "Draft" => @draft_count,
      "Submitted" => @submitted_count,
      "In Review" => @in_review_count,
      "Approved" => @approved_count
    }

    # Status Breakdown data for polar area chart
    @draft_count = Application.where(status: "draft").count
    @in_progress_count = Application.where(status: [ "submitted", "in_review" ]).count
    @approved_count = Application.where(status: "approved").count
    @rejected_count = Application.where(status: "rejected").count

    @status_chart_data = {
      "Draft" => @draft_count,
      "In Progress" => @in_progress_count,
      "Approved" => @approved_count,
      "Rejected" => @rejected_count
    }

    # Get base scope with includes
    scope = Application.includes(:user)
                       .with_attached_income_proof
                       .with_attached_residency_proof
                       .where.not(status: [:rejected, :archived])

    scope = apply_filters(scope, params[:filter])

    @pagy, @applications = pagy(scope, items: 20)

    # Always load reporting data
    load_quick_reports_data
  end

  def show
    @application = Application.includes(
      :user,
      :evaluations,
      :training_sessions,
      proof_reviews: :admin,
      proof_submission_audits: :user
    ).with_attached_income_proof
      .with_attached_residency_proof
      .with_attached_medical_certification
      .find(params[:id])
      
    # Preload and structure proof history data
    @proof_histories = {
      income: load_proof_history(:income),
      residency: load_proof_history(:residency)
    }
  end

  def edit; end

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
    
    # Set a thread-local variable to indicate we're reviewing a single proof
    # This will help the validation know the context
    Thread.current[:reviewing_single_proof] = true
    
    begin
      Rails.logger.info "Starting proof review in controller"
      Rails.logger.info "Parameters: proof_type=#{params[:proof_type]}, status=#{params[:status]}"

      reviewer.review(
        proof_type: params[:proof_type],
        status: params[:status],
        rejection_reason: params[:rejection_reason],
        notes: params[:notes]
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
          ).with_attached_income_proof
            .with_attached_residency_proof
            .with_attached_medical_certification
            .find(params[:id])
          
          # Load proof histories for partials
          @proof_histories = {
            income: load_proof_history(:income),
            residency: load_proof_history(:residency)
          }

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

  # Include application-related events (including vouchers and application creation)
  # Use a more flexible JSONB query to match application_id in metadata, regardless of string/integer type
  application_events = Event.where(
    action: [ 
      "voucher_assigned", "voucher_redeemed", "voucher_expired", "voucher_cancelled", 
      "application_created", "evaluator_assigned", "trainer_assigned", "application_auto_approved" 
    ]
  ).where("metadata->>'application_id' = ? OR metadata @> ?", 
    @application.id.to_s, 
    { application_id: @application.id }.to_json
  ).includes(:user).order(created_at: :desc)

  @audit_logs = (proof_reviews + status_changes + notifications + application_events)
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
          
          # Add JavaScript to immediately clean up modals and handle letter_opener return
          streams << turbo_stream.append_all("body", 
            tag.script(<<-JS.html_safe, type: "text/javascript")
              // Immediate cleanup (run right away)
              (function() {
                console.log("Executing immediate modal cleanup");
                // Remove overflow-hidden class
                document.body.classList.remove("overflow-hidden");

                // Hide all modals
                document.querySelectorAll('[data-modal-target="container"]').forEach(modal => {
                  modal.classList.add('hidden');
                  console.log("Hidden modal:", modal.id || 'unnamed modal');
                });

                // Trigger cleanup on modal controllers
                const controllers = document.querySelectorAll("[data-controller~='modal']");
                controllers.forEach((element) => {
                  try {
                    const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "modal");
                    if (controller && typeof controller.cleanup === "function") {
                      controller.cleanup();
                      console.log("Modal cleanup triggered immediately after proof review");
                    }
                  } catch(e) {
                    console.error("Error cleaning up modal:", e);
                  }
                });
              })();

              // Also handle when this tab becomes visible again (after letter_opener is closed)
              document.addEventListener("visibilitychange", function() {
                if (!document.hidden) {
                  console.log("Page became visible again - cleaning up modals");
                  // Hide all modals
                  document.querySelectorAll('[data-modal-target="container"]').forEach(modal => {
                    modal.classList.add('hidden');
                    console.log("Hidden modal on visibility change:", modal.id || 'unnamed modal');
                  });

                  // Remove overflow-hidden
                  document.body.classList.remove("overflow-hidden");

                  // Trigger cleanup on modal controllers
                  const controllers = document.querySelectorAll("[data-controller~='modal']");
                  controllers.forEach((element) => {
                    try {
                      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "modal");
                      if (controller && typeof controller.cleanup === "function") {
                        controller.cleanup();
                        console.log("Modal cleanup triggered on visibility change");
                      }
                    } catch(e) {
                      console.error("Error cleaning up modal:", e);
                    }
                  });
                }
              }, { once: true });
            JS
          )

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
    ensure
      # Always clear the thread-local variable to prevent affecting other operations
      Thread.current[:reviewing_single_proof] = nil
    end
  end

  def process_application_status(action)
    past_tense = { 'approve' => 'approved', 'reject' => 'rejected' }
    if @application.send("#{action}!")
      flash[:notice] = "Application #{past_tense[action.to_s]}."
      redirect_to admin_application_path(@application)
    else
      handle_application_failure(action)
    end
  rescue ::ActiveRecord::RecordInvalid => e
    handle_application_failure(action, e.record.errors.full_messages.to_sentence)
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
        notice: 'Evaluator successfully assigned'
    else
      redirect_to admin_application_path(@application),
        alert: 'Failed to assign evaluator'
    end
  end

  def assign_trainer
    @application = Application.find(params[:id])
    trainer = Trainer.find(params[:trainer_id])

    if @application.assign_trainer!(trainer)
      redirect_to admin_application_path(@application),
        notice: 'Trainer successfully assigned'
    else
      redirect_to admin_application_path(@application),
        alert: 'Failed to assign trainer'
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
        alert: 'Failed to schedule training session'
    end
  end

  def complete_training
    training_session = @application.training_sessions.find(params[:training_session_id])
    training_session.complete!

    redirect_to admin_application_path(@application),
      notice: 'Training session marked as completed'
  end

  def update_certification_status
    if @application.update_certification!(
        certification: params[:medical_certification],
        status: params[:status],
        verified_by: current_user,
        rejection_reason: params[:rejection_reason]
      )
      redirect_to admin_application_path(@application),
        notice: 'Medical certification status updated.'
    else
      redirect_to admin_application_path(@application),
        alert: 'Failed to update certification status.'
    end
  end

  def resend_medical_certification
    service = Applications::MedicalCertificationService.new(
      application: @application,
      actor: current_user
    )

    if service.request_certification
      redirect_to admin_application_path(@application),
        notice: 'Certification request sent successfully.'
    else
      redirect_to admin_application_path(@application),
        alert: "Failed to process certification request: #{service.errors.join(", ")}"
    end
  end

  def assign_voucher
    if @application.assign_voucher!(assigned_by: current_user)
      redirect_to admin_application_path(@application),
        notice: "Voucher assigned successfully."
    else
      redirect_to admin_application_path(@application),
        alert: "Failed to assign voucher. Please ensure all requirements are met."
    end
  end

  private

  def handle_application_failure(action, error_message = nil)
    error_message ||= @application.errors.full_messages.to_sentence
    flash[:alert] = "Failed to #{action} Application ##{@application.id}: #{error_message}"
    render :show, status: :unprocessable_entity
  end

  def load_proof_history(type)
    {
      reviews: filter_and_sort(@application.proof_reviews, type, :reviewed_at),
      audits:  filter_and_sort(@application.proof_submission_audits, type, :created_at)
    }
  rescue StandardError => e
    Rails.logger.error "Failed to load #{type} proof history: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { reviews: [], audits: [], error: true }
  end

  def filter_and_sort(collection, type, sort_method)
    collection.select { |item| item.proof_type.to_sym == type.to_sym }
              .sort_by(&sort_method)
              .reverse
  end

  def load_audit_logs
    return unless @application

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

    # Include application-related events (including vouchers and application creation)
    # Use a more flexible JSONB query to match application_id in metadata, regardless of string/integer type
    application_events = Event.where(
      action: %w[voucher_assigned voucher_redeemed voucher_expired voucher_cancelled application_created evaluator_assigned trainer_assigned application_auto_approved]
    ).where(
      "metadata->>'application_id' = ? OR metadata @> ?",
      @application.id.to_s,
      { application_id: @application.id }.to_json
    ).includes(:user).order(created_at: :desc)

    @audit_logs = (proof_reviews + status_changes + notifications + application_events)
                  .sort_by(&:created_at)
                  .reverse
  end

  def apply_filters(scope, filter)
    # First apply any filter from params[:filter] (from the filter links)
    scope = case filter
            when 'active'
              scope.active
            when 'in_progress'
              scope.where(status: :in_progress)
            when 'approved'
              scope.where(status: :approved)
            when 'proofs_needing_review'
              income_pending_ids = scope.where(income_proof_status: "not_reviewed").pluck(:id)
              residency_pending_ids = scope.where(residency_proof_status: "not_reviewed").pluck(:id)
              scope.where(id: income_pending_ids + residency_pending_ids)
            when 'awaiting_medical_response'
              scope.where(status: :awaiting_documents)
            when 'medical_certs_to_review'
              scope.where(medical_certification_status: "received")
            when 'training_requests'
              # Use our new scope to filter applications with pending training
              scope.with_pending_training
            else
              scope
            end

    # Apply status filter if present
    scope = scope.where(status: params[:status]) if params[:status].present?

    # Apply date range filter if present
    if params[:date_range].present?
      case params[:date_range]
      when 'current_fy'
        # Filter by current fiscal year
        current_fy_start = Date.new(fiscal_year, 7, 1)
        current_fy_end = Date.new(fiscal_year + 1, 6, 30)
        scope = scope.where(created_at: current_fy_start..current_fy_end)
      when 'previous_fy'
        # Filter by previous fiscal year
        previous_fy_start = Date.new(fiscal_year - 1, 7, 1)
        previous_fy_end = Date.new(fiscal_year, 6, 30)
        scope = scope.where(created_at: previous_fy_start..previous_fy_end)
      when 'last_30'
        # Filter by last 30 days
        scope = scope.where("created_at >= ?", 30.days.ago)
      when 'last_90'
        # Filter by last 90 days
        scope = scope.where("created_at >= ?", 90.days.ago)
      end
    end

    # Apply search filter if present
    if params[:q].present?
      search_term = "%#{params[:q]}%"
      # Join with users table to search on user fields
      scope = scope.joins(:user).where(
        "applications.id::text ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ? OR users.email ILIKE ?", 
        search_term, search_term, search_term, search_term
      )
    end
    scope
  end

  def sort_column
    params[:sort] || 'application_date'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end

  def filter_conditions
    # Define your filter conditions based on params[:filter]
    case params[:filter]
    when 'in_progress'
      { status: :in_progress }
    when 'approved'
      { status: :approved }
    when 'proofs_needing_review'
      { status: :proofs_needing_review }
    when 'awaiting_medical_response'
      { status: :awaiting_medical_response }
    else
      {}
    end
  end

  def set_application
    @application = Application.with_attached_income_proof
                              .with_attached_residency_proof
                              .with_attached_medical_certification
                              .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_applications_path, alert: 'Application not found'
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

  def load_quick_reports_data
    @current_fy = fiscal_year
    @previous_fy = @current_fy - 1

    # Current and previous fiscal year date ranges
    @current_fy_start = Date.new(@current_fy, 7, 1)
    @current_fy_end = Date.new(@current_fy + 1, 6, 30)
    @previous_fy_start = Date.new(@previous_fy, 7, 1)
    @previous_fy_end = Date.new(@current_fy, 6, 30)

    # Applications data
    @current_fy_applications = Application.where(created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_applications = Application.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Draft applications (started but not submitted)
    @current_fy_draft_applications = Application.where(status: :draft, created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_draft_applications = Application.where(status: :draft, created_at: @previous_fy_start..@previous_fy_end).count

    # Vouchers data
    @current_fy_vouchers = Voucher.where(created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_vouchers = Voucher.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Unredeemed vouchers
    @current_fy_unredeemed_vouchers = Voucher.where(created_at: @current_fy_start..@current_fy_end, status: :active).count
    @previous_fy_unredeemed_vouchers = Voucher.where(created_at: @previous_fy_start..@previous_fy_end, status: :active).count

    # Voucher values
    @current_fy_voucher_value = Voucher.where(created_at: @current_fy_start..@current_fy_end).sum(:initial_value)
    @previous_fy_voucher_value = Voucher.where(created_at: @previous_fy_start..@previous_fy_end).sum(:initial_value)

    # Training sessions
    @current_fy_trainings = TrainingSession.where(created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_trainings = TrainingSession.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Evaluation sessions
    @current_fy_evaluations = Evaluation.where(created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_evaluations = Evaluation.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Vendor activity
    @active_vendors = Vendor.joins(:voucher_transactions).distinct.count
    @recent_active_vendors = Vendor.joins(:voucher_transactions)
                                   .where("voucher_transactions.created_at >= ?", 1.month.ago)
                                   .distinct.count

    # MFR Data (previous full fiscal year)
    @mfr_applications_approved = Application.where(created_at: @previous_fy_start..@previous_fy_end, status: :approved).count
    @mfr_vouchers_issued = Voucher.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Chart data for applications
    @applications_chart_data = {
      current: { "Applications" => @current_fy_applications, "Draft Applications" => @current_fy_draft_applications },
      previous: { "Applications" => @previous_fy_applications, "Draft Applications" => @previous_fy_draft_applications }
    }

    # Chart data for vouchers
    @vouchers_chart_data = {
      current: { "Vouchers Issued" => @current_fy_vouchers, "Unredeemed Vouchers" => @current_fy_unredeemed_vouchers },
      previous: { "Vouchers Issued" => @previous_fy_vouchers, "Unredeemed Vouchers" => @previous_fy_unredeemed_vouchers }
    }

    # Chart data for services
    @services_chart_data = {
      current: { "Training Sessions" => @current_fy_trainings, "Evaluation Sessions" => @current_fy_evaluations },
      previous: { "Training Sessions" => @previous_fy_trainings, "Evaluation Sessions" => @previous_fy_evaluations }
    }

    # Chart data for MFR
    @mfr_chart_data = {
      current: { "Applications Approved" => @mfr_applications_approved, "Vouchers Issued" => @mfr_vouchers_issued },
      previous: { "Applications Approved" => 0, "Vouchers Issued" => 0 } # Empty for comparison
    }
  end
end
