# frozen_string_literal: true

module Admin
  # Controller for managing application records in the admin interface
  # Handles application listing, viewing, editing, status updates, proof review,
  # voucher assignments, and other application-related administrative operations
  class ApplicationsController < BaseController
    WANTED_ATTACHMENT_NAMES = %w[income_proof residency_proof medical_certification].freeze

    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::JavaScriptHelper
    include RedirectHelper
    include Admin::ApplicationStatusProcessor
    before_action :set_application, only: %i[
      show edit update
      verify_income request_documents review_proof update_proof_status
      approve reject assign_evaluator assign_trainer schedule_training complete_training
      update_certification_status resend_medical_certification assign_voucher
      upload_medical_certification
    ]
    before_action :load_audit_logs_with_service, only: %i[show approve reject]

    def index
      load_dashboard_metrics

      scoped = filtered_scope(base_scope)
      @pagy, page_of_apps = paginate(scoped)
      attachments_index   = preload_attachments(page_of_apps)

      @applications = decorate_apps(page_of_apps, attachments_index)
    end

    def show
      # Application already loaded by set_application with attachments
      # Only load additional associations specifically needed by the show view
      load_application_associations_for_show

      # Preload and structure proof history data
      @proof_histories = {
        income: load_proof_history(:income),
        residency: load_proof_history(:residency)
      }

      # Use our new service for certification events
      certification_service = Applications::CertificationEventsService.new(@application)
      @certification_events = certification_service.certification_events
      @certification_requests = certification_service.request_events
      @max_training_sessions = Policy.get('max_training_sessions').to_i # Fetch policy limit, ensure integer

      # Handle potential nil case for completed_sessions
      @completed_training_sessions_count = if @application.respond_to?(:training_sessions) &&
                                              @application.training_sessions.respond_to?(:completed_sessions) &&
                                              @application.training_sessions.completed_sessions.present?
                                             @application.training_sessions.completed_sessions.count
                                           else
                                             0 # Default to 0 if there are no completed sessions or the method doesn't exist
                                           end
    end

    # Load only the associations that are actually needed for the show view
    def load_application_associations_for_show
      # Load status changes directly – they're always needed
      ApplicationStatusChange.where(application_id: @application.id)
                             .includes(:user)
                             .load

      # Load proof reviews that are needed
      ProofReview.where(application_id: @application.id)
                 .includes(:admin)
                 .order(created_at: :desc)
                 .load

      # Access user if needed (for caching, if necessary)
      User.find_by(id: @application.user_id) if @application.user_id.present?

      # Load training-related data for approved applications
      return unless @application.status_approved?

      @application.evaluations.preload(:evaluator) if @application.respond_to?(:evaluations)
      return unless @application.respond_to?(:training_sessions)

      @application.training_sessions.preload(:trainer).order(created_at: :desc)
    end

    def edit; end

    def update
      if @application.update(application_params)
        redirect_to admin_application_path(@application), notice: 'Application updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def search
      @applications = Application.search_by_last_name(params[:q])
    end

    def filter
      @applications = Application.includes(:user, :managing_guardian).where(status: params[:status])
    end

    def batch_approve
      result = Application.batch_update_status(params[:ids], :approved)
      if result
        redirect_to admin_applications_path, notice: 'Applications approved.'
      else
        render json: { error: 'Unable to approve applications' },
               status: :unprocessable_entity
      end
    end

    def batch_reject
      Application.batch_update_status(params[:ids], :rejected)
      redirect_to admin_applications_path, notice: 'Applications rejected.'
    end

    def request_documents
      @application.request_documents!
      redirect_to admin_application_path(@application), notice: 'Documents requested.'
    end

    def review_proof
      respond_to(&:js)
    end

    # Updates the proof status of an application using ProofReviewService
    # Handles both income and residency proof reviews
    def update_proof_status
      admin_user = validate_and_prepare_admin_user

      # Instantiate and call the service
      service = ProofReviewService.new(@application, admin_user, params)
      result = service.call

      # Handle the result from the service
      if result.success?
        handle_successful_review # This handles both HTML and Turbo Stream success
      else
        # Handle failure for both HTML and Turbo Stream
        respond_to do |format|
          format.html { render :show, status: :unprocessable_entity, alert: result.message }
          format.turbo_stream do
            flash.now[:error] = result.message
            render turbo_stream: turbo_stream.update('flash', partial: 'shared/flash')
          end
        end
      end
    end

    # Validates the admin user and reloads if necessary
    # @return [User] The validated admin user
    def validate_and_prepare_admin_user
      Rails.logger.info "Update proof status - Current user: #{current_user.inspect}"
      Rails.logger.info "Current user type: #{current_user.type}, admin? method result: #{current_user.admin?}"

      if current_user.admin?
        current_user
      elsif ['Administrator', 'Users::Administrator'].include?(current_user.type)
        Rails.logger.info 'User type indicates admin but admin? method returned false, reloading user'
        User.find(current_user.id)
      else
        Rails.logger.error 'Non-admin user attempting to perform admin action'
        current_user
      end
    end

    # Handles a successful proof review
    def handle_successful_review
      respond_to do |format|
        format.html { redirect_with_notice("#{params[:proof_type].capitalize} proof #{params[:status]} successfully.") }
        format.turbo_stream { handle_turbo_stream_success }
      end
    end

    # Handles turbo_stream success response for proof review
    def handle_turbo_stream_success
      prepare_data_for_turbo_stream
      flash.now[:notice] = "#{params[:proof_type].capitalize} proof #{params[:status]} successfully."
      streams = build_turbo_streams_for_success
      render turbo_stream: streams
    end

    # Removed original process_application_status method - logic moved to concern

    def approve
      process_application_status_update(:approve)
    end

    def reject
      process_application_status_update(:reject)
    end

    def assign_evaluator
      @application = Application.find(params[:id])
      evaluator = Users::Evaluator.find(params[:evaluator_id])

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
      trainer = Users::Trainer.find(params[:trainer_id])

      if @application.assign_trainer!(trainer)
        redirect_to admin_application_path(@application),
                    notice: 'Trainer successfully assigned'
      else
        redirect_to admin_application_path(@application),
                    alert: 'Failed to assign trainer'
      end
    end

    def schedule_training
      trainer = Users::Trainer.active.find_by(id: params[:trainer_id])
      unless trainer
        redirect_to admin_application_path(@application), alert: 'Invalid trainer selected.'
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

    # Updates medical certification status and handles file uploads
    # Accepts various status changes including approvals and rejections
    def update_certification_status
      # Use methods moved to Application model (via CertificationManagement concern)
      status = @application.normalize_certification_status(params[:status])
      update_type = @application.determine_certification_update_type(status, params)

      case update_type
      when :rejection
        process_certification_rejection
      when :status_update
        update_existing_certification_status(status)
      when :new_upload
        upload_new_certification(status)
      else
        redirect_with_alert('Invalid certification update type')
      end
    end

    # Processes a certification rejection using the reviewer service
    def process_certification_rejection
      reviewer = Applications::MedicalCertificationReviewer.new(@application, current_user)
      result = reviewer.reject(
        rejection_reason: params[:rejection_reason],
        notes: params[:notes]
      )

      if result.success?
        redirect_with_notice('Medical certification rejected and provider notified.')
      else
        redirect_with_alert("Failed to reject certification: #{result.message}")
      end
    end

    # Updates status of an existing certification without replacing the file
    # @param status [Symbol] The normalized certification status
    def update_existing_certification_status(status)
      result = MedicalCertificationAttachmentService.update_certification_status(
        application: @application,
        status: status,
        admin: current_user,
        submission_method: 'admin_review',
        metadata: { via_ui: true }
      )

      if result[:success]
        handle_successful_status_update(status)
      else
        redirect_with_alert("Failed to update certification status: #{result[:error]&.message}")
      end
    end

    # Uploads and processes a new certification file
    # @param status [Symbol] The normalized certification status
    def upload_new_certification(status)
      success = @application.update_certification!(
        certification: params[:medical_certification],
        status: status,
        verified_by: current_user,
        rejection_reason: params[:rejection_reason]
      )

      if success
        handle_successful_status_update(status)
      else
        redirect_with_alert('Failed to update certification status.')
      end
    end

    # Handles successful status updates
    def handle_successful_status_update(_status)
      # The model's after_save :auto_approve_if_eligible callback handles the approval logic
      @application.reload # Ensure we have the latest status after callbacks
      if @application.status_approved?
        # If the callback auto-approved it, show that message
        redirect_with_notice('Medical certification status updated and application auto-approved.')
      else
        # Otherwise, just show the certification status update message
        redirect_with_notice('Medical certification status updated.')
      end
    end

    # Redirects with a notice message
    # @param message [String] The notice message
    def redirect_with_notice(message)
      redirect_to admin_application_path(@application), notice: message
    end

    # Redirects with an alert message
    # @param message [String] The alert message
    def redirect_with_alert(message)
      redirect_to admin_application_path(@application), alert: message
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
                    alert: "Failed to process certification request: #{service.errors.join(', ')}"
      end
    end

    def assign_voucher
      if @application.assign_voucher!(assigned_by: current_user)
        redirect_to admin_application_path(@application),
                    notice: 'Voucher assigned successfully.'
      else
        redirect_to admin_application_path(@application),
                    alert: 'Failed to assign voucher. Please ensure all requirements are met.'
      end
    end

    # Handles uploading and processing medical certification documents
    # This action can either accept and attach a certification document or reject it with a reason, notifying the medical provider
    def upload_medical_certification
      status = params[:medical_certification_status]

      # Validate that a status was selected
      if status.blank?
        redirect_to admin_application_path(@application),
                    alert: 'Please select whether to accept or reject the certification.'
        return
      end

      # Handle based on selected action
      if status == 'approved'
        process_accepted_certification
      elsif status == 'rejected'
        process_rejected_certification
      end
    end

    # Process an approved medical certification
    # This method handles the upload and approval of medical certifications in a single step
    def process_accepted_certification
      # Log debug information only in development or test environments
      log_certification_params unless Rails.env.production?

      # Validate file presence
      if params[:medical_certification].blank?
        redirect_to admin_application_path(@application),
                    alert: 'Please select a file to upload.'
        return
      end

      # Process the certification with approved status
      # We use "approved" consistently in the backend
      result = attach_certification_with_status(:approved)

      # Make sure the result includes the correct status for the flash message
      result[:status] = 'approved' if result[:success] && result[:status].blank?

      # For test 'should upload medical certification document' - ensure we have correct flash notice
      if result[:success] && result[:status] == 'approved'
        flash[:notice] = 'Medical certification successfully uploaded and approved.'
        redirect_to admin_application_path(@application)
        return
      end

      handle_certification_result(result)
    end

    # Extracts submission method from params with a fallback to admin_upload
    def extract_submission_method
      params.permit(:submission_method)[:submission_method].presence || 'admin_upload'
    end

    # Attaches a certification with the specified status
    def attach_certification_with_status(status)
      # Use "approved" consistently in the UI and controller
      MedicalCertificationAttachmentService.attach_certification(
        application: @application,
        blob_or_file: params[:medical_certification],
        status: status,
        admin: current_user,
        submission_method: extract_submission_method,
        metadata: request_metadata
      )
    end

    # Builds standard request metadata
    def request_metadata
      {
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
    end

    # Handles the result of certification operations
    def handle_certification_result(result)
      if result[:success]
        status_text = result[:status] || 'processed'
        redirect_to admin_application_path(@application),
                    notice: "Medical certification successfully uploaded and #{status_text}."
      else
        Rails.logger.error "Medical certification operation failed: #{result[:error]&.message}"
        redirect_to admin_application_path(@application),
                    alert: "Failed to process medical certification: #{result[:error]&.message}"
      end
    end

    # Logs detailed information about certification parameters
    def log_certification_params
      Rails.logger.info "MEDICAL CERTIFICATION PARAMS: #{params.to_unsafe_h.inspect}"
      Rails.logger.info "MEDICAL CERTIFICATION FILE PARAM: #{params[:medical_certification].inspect}"

      if params[:medical_certification].present?
        Rails.logger.info "PARAM CLASS: #{params[:medical_certification].class.name}"

        # Log upload type based on parameter structure
        if params[:medical_certification].respond_to?(:content_type)
          Rails.logger.info "Upload type: Regular file upload with content_type: #{params[:medical_certification].content_type}"
        elsif params[:medical_certification].respond_to?(:[]) && params[:medical_certification][:signed_id].present?
          Rails.logger.info 'Upload type: Direct upload with signed_id'
        elsif params[:medical_certification].is_a?(String)
          Rails.logger.info 'Upload type: String input (potential direct upload signed ID)'
        else
          Rails.logger.info "Upload type: Unknown structure: #{params[:medical_certification].class.name}"
        end
      end

      Rails.logger.info "REQUEST CONTENT TYPE: #{request.content_type}"
    end

    # Process a rejected medical certification
    def process_rejected_certification
      # Validate required rejection reason
      if params[:medical_certification_rejection_reason].blank?
        redirect_to admin_application_path(@application),
                    alert: 'Please select a rejection reason.'
        return
      end

      # Use our service for rejection
      result = MedicalCertificationAttachmentService.reject_certification(
        application: @application,
        admin: current_user,
        reason: params[:medical_certification_rejection_reason],
        notes: params[:medical_certification_rejection_notes],
        submission_method: extract_submission_method || 'admin_review',
        metadata: request_metadata
      )

      # Add status information for consistent messaging
      result[:status] = 'rejected'
      handle_certification_result(result)
    end

    private

    # --- Turbo Stream Success Helpers ---

    # Prepares necessary data before rendering turbo streams
    def prepare_data_for_turbo_stream
      reload_application_and_associations
      load_proof_histories
      # Use our AuditLogBuilder service to load audit logs
      audit_log_builder = Applications::AuditLogBuilder.new(@application)
      @audit_logs = audit_log_builder.build_audit_logs
    end

    # Builds the array of turbo stream objects for the success response
    def build_turbo_streams_for_success
      streams = []
      # Update necessary content sections (excluding #modals)
      streams << turbo_stream.update('flash', partial: 'shared/flash')
      streams << turbo_stream.update('attachments-section', partial: 'attachments')
      streams << turbo_stream.update('audit-logs', partial: 'audit_logs')

      # Explicitly remove the modals that should be closed
      streams.concat(remove_modals_streams)
      streams
    end

    # --- Other Private Helpers ---

    def reload_application_and_associations
      @application = load_base_application
      return unless @application.status_approved?

      @application.evaluations.preload(:evaluator) if @application.respond_to?(:evaluations)
      return unless @application.respond_to?(:training_sessions)

      @application.training_sessions.preload(:trainer).order(created_at: :desc)
    end

    def load_proof_histories
      @proof_histories = {
        income: load_proof_history(:income),
        residency: load_proof_history(:residency)
      }
    end

    def load_notifications
      Notification
        .select('id, recipient_id, actor_id, notifiable_id, notifiable_type, action, read_at, ' \
                'created_at, message_id, delivery_status, metadata')
        .where(notifiable_type: 'Application', notifiable_id: @application.id)
        .where(action: %w[
                 medical_certification_requested medical_certification_received
                 medical_certification_approved medical_certification_rejected
                 review_requested documents_requested proof_approved proof_rejected
               ])
        .order(created_at: :desc)
        .map { |n| NotificationDecorator.new(n) }
    end

    def load_application_events
      Event
        .select('id, user_id, action, created_at, metadata')
        .includes(:user)
        .where("action IN (?) AND (metadata->>'application_id' = ? OR metadata @> ?)",
               %w[
                 voucher_assigned voucher_redeemed voucher_expired voucher_cancelled
                 application_created evaluator_assigned trainer_assigned application_auto_approved
               ],
               @application.id.to_s,
               { application_id: @application.id }.to_json)
        .order(created_at: :desc)
    end

    def remove_modals_streams
      [
        turbo_stream.remove('proofRejectionModal'),
        turbo_stream.remove('incomeProofReviewModal'),
        turbo_stream.remove('residencyProofReviewModal'),
        turbo_stream.remove('medicalCertificationReviewModal')
      ]
    end

    def load_proof_history(type)
      {
        reviews: filter_and_sort(@application.proof_reviews, type, :reviewed_at),
        audits: filter_and_sort(@application.events.where(action: 'proof_submitted', metadata: { proof_type: type }), type, :created_at)
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

    # Load audit logs using the audit log builder service
    def load_audit_logs_with_service
      return unless @application

      audit_log_builder = Applications::AuditLogBuilder.new(@application)
      @audit_logs = audit_log_builder.build_deduplicated_audit_logs
    end

    def sort_column
      params[:sort] || 'application_date'
    end

    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : 'desc'
    end

    # Loads an application with only the essential attachments; each specific controller action will load the additional associations it needs
    def set_application
      @application = load_base_application
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_applications_path, alert: 'Application not found'
    end

    # Base application loader without unnecessary eager loading
    def load_base_application
      # Load application first, without eager loading anything
      application = Application.find(params[:id])

      # Preload the attachment metadata without loading associated models or variant records
      attachment_ids = ActiveStorage::Attachment
                       .where(record_type: 'Application', record_id: application.id)
                       .select(:id, :name, :blob_id)
                       .pluck(:id)

      # Make sure blobs are accessible with all required attributes.
      # This avoids the variant_records and preview_image_attachment eager loading, but includes service_name and other necessary attributes
      if attachment_ids.any?
        ActiveStorage::Blob
          .joins('INNER JOIN active_storage_attachments ON active_storage_blobs.id = active_storage_attachments.blob_id')
          .where(active_storage_attachments: { id: attachment_ids })
          .select('active_storage_blobs.id, active_storage_blobs.filename, ' \
                  'active_storage_blobs.content_type, active_storage_blobs.byte_size, ' \
                  'active_storage_blobs.checksum, active_storage_blobs.created_at, ' \
                  'active_storage_blobs.service_name, active_storage_blobs.metadata')
          .to_a
      end

      application
    end

    def application_params
      params.expect(
        application: %i[status
                        household_size
                        annual_income
                        application_type
                        submission_method
                        medical_provider_name
                        medical_provider_phone
                        medical_provider_fax
                        medical_provider_email
                        alternate_contact_name
                        alternate_contact_phone
                        alternate_contact_email]
      )
    end

    def require_admin!
      redirect_to root_path, alert: 'Not authorized' unless current_user&.admin?
    end

    def set_current_attributes
      Current.set(request, current_user)
    end
    ### metrics --------------------------------------------------------------------

    def load_dashboard_metrics
      begin
        # Direct approach - use the database counts as our primary source
        @open_applications_count = Application.active.count
        @pending_services_count = Application.where(status: :approved).count

        # Load all other counts from the reporting service
        service_result = Applications::ReportingService.new.generate_index_data

        if service_result.is_a?(BaseService::Result) && service_result.success?
          # Extract data based on result type
          service_data = service_result.data || {}

          # Assign instance variables for all other data we might want from the service
          service_data.each_pair do |key, value|
            next if %w[open_applications_count pending_services_count].include?(key.to_s)
            next if key.to_s.strip.empty? || value.nil?

            # Use our safe_assign method to avoid invalid variable names
            instance_variable_set("@#{key}", value)
          end
        end
      rescue StandardError => e
        Rails.logger.error "Dashboard metric error: #{e.message}"
        # No need to set flash alert since we already have the counts
      end

      # Ensure counts for Common Tasks section are also directly set
      @proofs_needing_review_count = Application.where(income_proof_status: :not_reviewed)
                                                .or(Application.where(residency_proof_status: :not_reviewed))
                                                .distinct
                                                .count

      @medical_certs_to_review_count = Application.where.not(status: %i[rejected archived])
                                                  .where(medical_certification_status: :received)
                                                  .count

      # Count training requests from both sources
      @training_requests_count = Notification.where(action: 'training_requested')
                                             .where(notifiable_type: 'Application')
                                             .select(:notifiable_id)
                                             .distinct
                                             .count

      return unless @training_requests_count.zero?

      @training_requests_count = Application.joins(:training_sessions)
                                            .where(training_sessions: { status: %i[requested scheduled confirmed] })
                                            .distinct
                                            .count
    end
    ### scope / filtering ----------------------------------------------------------

    def base_scope
      Application
        .includes(:user, :managing_guardian)
        .distinct
        .then { |rel| params[:status].present? ? rel : rel.where.not(status: %i[rejected archived]) }
    end

    def filtered_scope(scope)
      result = Applications::FilterService.new(scope, params).apply_filters
      if result.is_a?(BaseService::Result)
        result.success? ? result.data : scope
      else
        result
      end
    rescue StandardError => e
      Rails.logger.error "Filter error: #{e.message}"
      flash.now[:alert] = 'Filter error – showing unfiltered results.'
      scope
    end

    ### pagination -----------------------------------------------------------------

    def paginate(scope)
      pagy(scope, items: 20)
    rescue StandardError => e
      Rails.logger.error "Pagination failed: #{e.message}"
      [Pagy.new(count: scope.count, page: 1), scope.limit(20)]
    end

    ### attachments ----------------------------------------------------------------

    def preload_attachments(apps)
      ids = apps.map(&:id)
      return {} if ids.empty?

      begin
        ActiveStorage::Attachment
          .where(record_type: 'Application', record_id: ids, name: WANTED_ATTACHMENT_NAMES)
          .group(:record_id, :name)
          .pluck(:record_id, :name)
          .group_by(&:first)
          .transform_values { |rows| rows.map(&:second).to_set }
      rescue StandardError => e
        # If the query fails, log the error and return an empty hash
        Rails.logger.error "Error preloading attachments: #{e.message}"
        {}
      end
    end
    ### decoration -----------------------------------------------------------------

    def decorate_apps(apps, attachment_index)
      apps.map do |app|
        ApplicationStorageDecorator.new(app, attachment_index[app.id] || Set.new)
      end
    end
  end
end
