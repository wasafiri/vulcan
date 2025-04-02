# frozen_string_literal: true

module Admin
  # Controller for managing application records in the admin interface
  # Handles application listing, viewing, editing, status updates, proof review,
  # voucher assignments, and other application-related administrative operations
  class ApplicationsController < BaseController
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::JavaScriptHelper
    before_action :set_application, only: %i[
      show edit update
      verify_income request_documents review_proof update_proof_status
      approve reject assign_evaluator assign_trainer schedule_training complete_training
      update_certification_status resend_medical_certification assign_voucher
      upload_medical_certification
    ]
    before_action :load_audit_logs_with_service, only: %i[show approve reject]

    def index
      # Load index data using the reporting service
      reporting_service = Applications::ReportingService.new
      report_data = reporting_service.generate_index_data

      # Assign instance variables from the report data
      report_data.each do |key, value|
        instance_variable_set("@#{key}", value)
      end

      # Get base scope – avoid using with_attached_* which triggers eager loading
      scope = Application.includes(:user)
                         .distinct
                         .where.not(status: %i[rejected archived])

      # Apply filters using the filter service
      filter_service = Applications::FilterService.new(scope, params)
      scope = filter_service.apply_filters

      # Use pagy for pagination but apply our decorator to prevent unnecessary eager loading
      @pagy, applications = pagy(scope, items: 20)
      @applications = applications.map { |app| ApplicationStorageDecorator.new(app) }
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
      @applications = Application.includes(:user).where(status: params[:status])
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

    def update_proof_status
      Rails.logger.info "Update proof status - Current user: #{current_user.inspect}"
      Rails.logger.info "Current user type: #{current_user.type}, admin? method result: #{current_user.admin?}"
      Rails.logger.info "Current user class: #{current_user.class}, class name: #{current_user.class.name}"

      # Ensure we're using a properly loaded administrator user
      admin_user = if current_user.admin?
                     current_user
                  else
                    # Fallback to reload the user if admin? check fails but type is correct
                    if current_user.type == 'Administrator' || current_user.type == 'Users::Administrator'
                      Rails.logger.info "User type indicates admin but admin? method returned false, reloading user"
                      User.find(current_user.id)
                    else
                      Rails.logger.error "Non-admin user attempting to perform admin action"
                      current_user
                    end
                   end

      Rails.logger.info "Admin user prepared for proof review: #{admin_user.inspect}"
      Rails.logger.info "Prepared admin - Type: #{admin_user.type}, admin? result: #{admin_user.admin?}"

      reviewer = Applications::ProofReviewer.new(@application, admin_user)
      Thread.current[:reviewing_single_proof] = true

      log_proof_review_start

      reviewer.review(
        proof_type: params[:proof_type],
        status: params[:status],
        rejection_reason: params[:rejection_reason],
        notes: params[:notes]
      )
      Rails.logger.info 'Proof review completed successfully'

      respond_to do |format|
        format.html { handle_html_success }
        format.turbo_stream { handle_turbo_stream_success }
      end
    rescue StandardError => e
      Rails.logger.error "Failed to update proof status: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      respond_to do |format|
        format.html { handle_html_error(e) }
        format.turbo_stream { handle_turbo_stream_error(e) }
      end
    ensure
      Thread.current[:reviewing_single_proof] = nil
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

  def update_certification_status
    status = params[:status]&.to_sym
    
    # Use the new reviewer service for rejections
    if status == :rejected && params[:rejection_reason].present?
      reviewer = Applications::MedicalCertificationReviewer.new(@application, current_user)
      result = reviewer.reject(
        rejection_reason: params[:rejection_reason],
        notes: params[:notes]
      )
      
      if result[:success]
        redirect_to admin_application_path(@application),
                    notice: 'Medical certification rejected and provider notified.'
      else
        redirect_to admin_application_path(@application),
                    alert: "Failed to reject certification: #{result[:error]}"
      end
    else
      # Use the existing method for other statuses
      if @application.update_certification!(
        certification: params[:medical_certification],
        status: status,
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
  # This action can either accept and attach a certification document
  # or reject it with a reason, notifying the medical provider
  def upload_medical_certification
    status = params[:medical_certification_status]

    # Handle based on selected action
    if status == "accepted"
      process_accepted_certification
    elsif status == "rejected"
      process_rejected_certification
    else
      redirect_to admin_application_path(@application),
                  alert: 'Please select whether to accept or reject the certification.'
    end
  end

  # Process an accepted medical certification
  def process_accepted_certification
    Rails.logger.info "MEDICAL CERTIFICATION PARAMS: #{params.to_unsafe_h.inspect}"
    Rails.logger.info "MEDICAL CERTIFICATION FILE PARAM: #{params[:medical_certification].inspect}"
    Rails.logger.info "MEDICAL CERTIFICATION FILE PARAM CLASS: #{params[:medical_certification].class.name}" if params[:medical_certification].present?
    
    if params[:medical_certification].blank?
      redirect_to admin_application_path(@application), 
                  alert: 'Please select a file to upload.'
      return
    end

    # Use the new MedicalCertificationAttachmentService for reliable uploads
    submission_method = params[:submission_method].presence || 'admin_upload'
    
    result = MedicalCertificationAttachmentService.attach_certification(
      application: @application,
      blob_or_file: params[:medical_certification],
      status: :accepted,
      admin: current_user,
      submission_method: submission_method,
      metadata: {
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
    )
    
    if result[:success]
      redirect_to admin_application_path(@application),
                  notice: 'Medical certification successfully uploaded and accepted.'
    else
      Rails.logger.error "Medical certification upload failed: #{result[:error]&.message}"
      redirect_to admin_application_path(@application),
                  alert: "Failed to upload medical certification: #{result[:error]&.message}"
    end
  end

  # Process a rejected medical certification
  def process_rejected_certification
    # Validate required rejection reason
    if params[:medical_certification_rejection_reason].blank?
      redirect_to admin_application_path(@application),
                  alert: 'Please select a rejection reason.'
      return
    end

    # Use our new service for rejection
    result = MedicalCertificationAttachmentService.reject_certification(
      application: @application,
      admin: current_user,
      reason: params[:medical_certification_rejection_reason],
      notes: params[:medical_certification_rejection_notes],
      submission_method: params[:submission_method].presence || 'admin_review',
      metadata: {
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
    )

    if result[:success]
      redirect_to admin_application_path(@application),
                  notice: 'Medical certification rejected and provider notified.'
    else
      redirect_to admin_application_path(@application),
                  alert: "Failed to reject certification: #{result[:error]&.message}"
    end
  end

    private

    def log_proof_review_start
      Rails.logger.info 'Starting proof review in controller'
      Rails.logger.info "Parameters: proof_type=#{params[:proof_type]}, status=#{params[:status]}"
    end

    def handle_html_success
      flash[:notice] = "#{params[:proof_type].capitalize} proof #{params[:status]} successfully."
      redirect_to admin_application_path(@application)
    end

    def handle_turbo_stream_success
      reload_application_and_associations
      load_proof_histories

      # Use our new AuditLogBuilder service to load audit logs
      audit_log_builder = Applications::AuditLogBuilder.new(@application)
      @audit_logs = audit_log_builder.build_audit_logs

      flash.now[:notice] = "#{params[:proof_type].capitalize} proof #{params[:status]} successfully."
      streams = remove_modals_streams.concat(update_content_streams)
      streams << append_cleanup_js

      render turbo_stream: streams
    end

    def handle_html_error(error)
      flash[:error] = "Failed to update proof status: #{error.message}"
      render :show, status: :unprocessable_entity
    end

    def handle_turbo_stream_error(error)
      flash.now[:error] = "Failed to update proof status: #{error.message}"
      render turbo_stream: turbo_stream.update('flash', partial: 'shared/flash')
    end

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

    def update_content_streams
      [
        turbo_stream.update('flash', partial: 'shared/flash'),
        turbo_stream.update('attachments-section', partial: 'attachments'),
        turbo_stream.update('audit-logs', partial: 'audit_logs'),
        turbo_stream.update('modals', partial: 'modals')
      ]
    end

    def append_cleanup_js
      turbo_stream.append_all('body',
                              view_context.tag.script(cleanup_js, type: 'text/javascript'))
    end

    def cleanup_js
      <<-JS.html_safe.strip_heredoc
        (function() {
          console.log('Executing immediate modal cleanup');
          document.body.classList.remove('overflow-hidden');
          document.querySelectorAll('[data-modal-target="container"]').forEach(function(modal) {
            modal.classList.add('hidden');
            console.log('Hidden modal:', modal.id || 'unnamed modal');
          });
          document.querySelectorAll("[data-controller~='modal']").forEach(function(element) {
            try {
              var controller = window.Stimulus.getControllerForElementAndIdentifier(element, 'modal');
              if (controller && typeof controller.cleanup === 'function') {
                controller.cleanup();
                console.log('Modal cleanup triggered immediately after proof review');
              }
            } catch(e) {
              console.error('Error cleaning up modal:', e);
            }
          });
        })();
        document.addEventListener('visibilitychange', function() {
          if (!document.hidden) {
            console.log('Page became visible again - cleaning up modals');
            document.querySelectorAll('[data-modal-target="container"]').forEach(function(modal) {
              modal.classList.add('hidden');
              console.log('Hidden modal on visibility change:', modal.id || 'unnamed modal');
            });
            document.body.classList.remove('overflow-hidden');
            document.querySelectorAll("[data-controller~='modal']").forEach(function(element) {
              try {
                var controller = window.Stimulus.getControllerForElementAndIdentifier(element, 'modal');
                if (controller && typeof controller.cleanup === 'function') {
                  controller.cleanup();
                  console.log('Modal cleanup triggered on visibility change');
                }
              } catch(e) {
                console.error('Error cleaning up modal:', e);
              }
            });
          }
        }, { once: true });
      JS
    end

    def handle_application_failure(action, error_message = nil)
      error_message ||= @application.errors.full_messages.to_sentence
      flash[:alert] = "Failed to #{action} Application ##{@application.id}: #{error_message}"
      render :show, status: :unprocessable_entity
    end

    def load_proof_history(type)
      {
        reviews: filter_and_sort(@application.proof_reviews, type, :reviewed_at),
        audits: filter_and_sort(@application.proof_submission_audits, type, :created_at)
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
      @audit_logs = audit_log_builder.build_audit_logs
    end

    def sort_column
      params[:sort] || 'application_date'
    end

    def sort_direction
      %w[asc desc].include?(params[:direction]) ? params[:direction] : 'desc'
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

    # Loads an application with only the essential attachments
    # Each specific controller action will load the additional associations it needs
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
      # This avoids the variant_records and preview_image_attachment eager loading,
      # but includes service_name and other necessary attributes.
      if attachment_ids.any?
        ActiveStorage::Blob
          .joins('INNER JOIN active_storage_attachments ON active_storage_blobs.id = active_storage_attachments.blob_id')
          .where('active_storage_attachments.id IN (?)', attachment_ids)
          .select('active_storage_blobs.id, active_storage_blobs.filename, ' \
                  'active_storage_blobs.content_type, active_storage_blobs.byte_size, ' \
                  'active_storage_blobs.checksum, active_storage_blobs.created_at, ' \
                  'active_storage_blobs.service_name, active_storage_blobs.metadata')
          .to_a
      end

      application
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
      redirect_to root_path, alert: 'Not authorized' unless current_user&.admin?
    end

    def set_current_attributes
      Current.set(request, current_user)
    end
  end
end
