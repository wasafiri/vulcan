# frozen_string_literal: true

module ConstituentPortal
  # Controller handling application creation, updates, and related actions
  # for constituents. This controller has been refactored to follow the
  # Single Responsibility Principle with smaller, focused methods.
  class ApplicationsController < ApplicationController
    include ParamCasting # Contains boolean fields found throughout the application
    # Define Structs for data objects at the class level to avoid recreation on each request

    # Represents medical provider contact information
    MedicalProviderInfo = Struct.new(:name, :phone, :fax, :email, keyword_init: true) do
      def present?
        name.present? || phone.present? || fax.present? || email.present?
      end

      def valid?
        name.present? && phone.present? && email.present?
      end

      def valid_phone?
        phone.present? && phone.match?(/\A[\d\-\(\)\s\.]+\z/)
      end

      def valid_email?
        email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
      end

      def to_h
        {
          name: name,
          phone: phone,
          fax: fax,
          email: email
        }
      end
    end

    # Represents a physical address
    Address = Struct.new(:physical_address_1, :physical_address_2, :city, :state, :zip_code, keyword_init: true) do
      def full_address
        [physical_address_1, physical_address_2, "#{city}, #{state} #{zip_code}"].compact.join("\n")
      end

      def valid?
        physical_address_1.present? && city.present? && state.present? && zip_code.present?
      end

      def to_h
        {
          physical_address_1: physical_address_1,
          physical_address_2: physical_address_2,
          city: city,
          state: state,
          zip_code: zip_code
        }
      end
    end

    # Represents a result from document attachment operations
    ProofResult = Struct.new(:success, :type, :message, keyword_init: true) do
      def success?
        success == true
      end

      def failure?
        !success?
      end

      def to_h
        {
          success: success,
          type: type,
          message: message
        }
      end
    end
    # Custom exceptions for better error handling
    class UserAttributeUpdateError < StandardError; end
    class ApplicationCreationError < StandardError; end
    class DisabilityValidationError < StandardError; end

    #----------------------------------------------------------------------
    # Common Utility Methods
    #----------------------------------------------------------------------

    # Log a debug message in development or test environment
    # @param message [String] The message to log
    def log_debug(message)
      Rails.logger.debug(message) if Rails.env.local?
    end

    # Log an error message with optional exception details
    # @param message [String] The error message
    # @param exception [Exception, nil] Optional exception for stack trace
    def log_error(message, exception = nil)
      Rails.logger.error(message)
      Rails.logger.error(exception.backtrace.join("\n")) if exception&.backtrace
    end

    # Redirect with a notice message
    # @param path [String] The path to redirect to
    # @param notice [String] The notice message
    def redirect_with_notice(path, notice)
      redirect_to path, notice: notice
    end

    # Redirect with an alert message
    # @param path [String] The path to redirect to
    # @param alert [String] The alert message
    def redirect_with_alert(path, alert)
      redirect_to path, alert: alert
    end

    # Handle transaction failure with consistent logging
    # @param exception [Exception] The exception that occurred
    # @param context [String] Context information for the error
    def handle_transaction_failure(exception, context)
      log_error("Transaction failed during #{context}: #{exception.message}", exception)
      false
    end
    before_action :authenticate_user!, except: [:fpl_thresholds]
    before_action :require_constituent!, except: [:fpl_thresholds]
    before_action :set_application, only: %i[show edit update verify submit]
    before_action :ensure_editable, only: %i[edit update]
    before_action :cast_boolean_params, only: %i[create update]
    before_action :set_paper_application_context, if: -> { Rails.env.test? }

    # Override current_user for tests
    def current_user
      if Rails.env.test? && ENV['TEST_USER_ID'].present?
        @current_user ||= User.find_by(id: ENV.fetch('TEST_USER_ID', nil))
        return @current_user if @current_user
      end
      super
    end

    def index
      @applications = current_user.applications.order(created_at: :desc)
    end

    def show
      @certification_requests = Notification.where(
        notifiable: @application,
        action: 'medical_certification_requested'
      ).order(created_at: :desc)
    end

    def new
      @application = current_user.applications.new
      @application.medical_provider_attributes ||= {}

      setup_dependent_application
      setup_address_for_form
    end

    def edit; end

    private

    # Set up the application for dependent users based on params
    # @return [void]
    def setup_dependent_application
      if params[:user_id].present?
        setup_specific_dependent_application
      elsif for_dependent_application?
        setup_guardian_application_context
      end
    end

    # Set up application for a specific dependent
    # @return [void]
    def setup_specific_dependent_application
      dependent = current_user.dependents.find_by(id: params[:user_id])
      return unless dependent

      @application.user = dependent
      @application.user_id = dependent.id
      @application.managing_guardian_id = current_user.id
    end

    # Set up guardian context for dependent application without selecting specific dependent
    # @return [void]
    def setup_guardian_application_context
      @application.managing_guardian_id = current_user.id
      # Don't set user_id yet - it will be set when the user selects a dependent
    end

    # Check if this is a dependent application based on params
    # @return [Boolean]
    def for_dependent_application?
      ['false', false].include?(params[:for_self])
    end

    # Pre-populate address fields from user profile
    # @return [void]
    def setup_address_for_form
      @address = Address.new(
        physical_address_1: current_user.physical_address_1,
        physical_address_2: current_user.physical_address_2,
        city: current_user.city,
        state: current_user.state,
        zip_code: current_user.zip_code
      )
    end

    public

    # Create a new application using clean service layer architecture
    # Form handles validation, ApplicationCreator handles persistence
    # @return [void] Redirects to application path or renders form with errors
    def create
      @form = ApplicationForm.new(
        current_user: current_user,
        params: params
      )

      return render_form_errors unless @form.valid?

      result = Applications::ApplicationCreator.call(@form)

      if result.success?
        redirect_to_app(result.application)
      else
        # Handle service layer errors
        @application = result.application || Application.new(filtered_application_params)
        result.error_messages.each do |message|
          @application.errors.add(:base, message)
        end

        initialize_address_and_provider_for_form
        render :new, status: :unprocessable_entity
      end
    end

    def render_form_errors
      # Transfer form errors to application for view compatibility
      @application = Application.new(filtered_application_params)
      @form.errors.each do |error|
        @application.errors.add(error.attribute, error.message)
      end

      initialize_address_and_provider_for_form
      render :new, status: :unprocessable_entity
    end

    def render_update_form_errors
      # Transfer form errors to existing application for view compatibility
      @form.errors.each do |error|
        @application.errors.add(error.attribute, error.message)
      end

      prepare_medical_provider_for_edit
      render :edit, status: :unprocessable_entity
    end

    def initialize_address_and_provider_for_form
      initialize_address
      build_medical_provider_for_form
    end

    # Apply medical provider details from params
    # @param application [Application] The application to update
    def apply_medical_provider_details(application)
      provider_info = extract_medical_provider_info

      if provider_info
        set_provider_fields(application, provider_info)
        log_debug("Setting medical provider: #{provider_info.to_h}")
      else
        log_debug('No medical provider data found in params')
      end

      log_final_provider_state(application)
    end

    # Extract medical provider info from various param locations
    # @return [MedicalProviderInfo, nil] Provider info if found, nil otherwise
    def extract_medical_provider_info
      # 1. Check for nested attributes under application params
      if params.dig(:application, :medical_provider_attributes).present?
        build_provider_from_params(params[:application][:medical_provider_attributes])
      # 2. Check for top-level medical_provider params (used in tests)
      elsif params[:medical_provider].present?
        build_provider_from_params(params[:medical_provider])
      # 3. Fall back to @medical_provider instance variable if available
      elsif @medical_provider.present? && @medical_provider.is_a?(MedicalProviderInfo)
        @medical_provider
      end
    end

    # Build MedicalProviderInfo from param attributes
    # @param mp_attrs [Hash] Medical provider attributes
    # @return [MedicalProviderInfo] Provider info object
    def build_provider_from_params(mp_attrs)
      MedicalProviderInfo.new(
        name: mp_attrs[:name],
        phone: mp_attrs[:phone],
        fax: mp_attrs[:fax],
        email: mp_attrs[:email]
      )
    end

    # Log the final state of medical provider fields
    # @param application [Application] The application to log state for
    def log_final_provider_state(application)
      log_debug("Final medical provider details: name=#{application.medical_provider_name}, " \
                "phone=#{application.medical_provider_phone}, " \
                "email=#{application.medical_provider_email}")
    end

    # Helper method to set provider fields on application
    # @param application [Application] The application to update
    # @param provider_info [MedicalProviderInfo] The provider info to use
    def set_provider_fields(application, provider_info)
      # Only update fields that are actually present in the provided info
      # This avoids accidentally overwriting existing values with blank ones
      application.medical_provider_name = provider_info.name if provider_info.name.present?
      application.medical_provider_phone = provider_info.phone if provider_info.phone.present?
      application.medical_provider_fax = provider_info.fax if provider_info.fax.present?
      application.medical_provider_email = provider_info.email if provider_info.email.present?

      # Always log what we're actually setting
      log_debug("Setting provider fields on application #{application.id}:")
      log_debug("  name: #{provider_info.name.presence || '[not provided]'}")
      log_debug("  phone: #{provider_info.phone.presence || '[not provided]'}")
      log_debug("  email: #{provider_info.email.presence || '[not provided]'}")
    end

    # Save application and create event log
    # @return [Boolean] Whether save was successful
    def save_application_with_event_log
      return false unless @application.valid?

      @application.save!

      # Log the initial application creation event
      AuditEventService.log(
        action: 'application_created',
        actor: current_user,
        auditable: @application,
        metadata: {
          submission_method: 'online',
          initial_status: @application.status
        }
      )

      true
    rescue StandardError => e
      log_error('Failed to save application', e)
      log_debug("Application errors: #{@application.errors.full_messages}") if @application&.errors&.any?
      false
    end

    # Handle the result of application creation
    # @param success [Boolean] Whether creation was successful
    def handle_application_creation_result(success)
      if success
        # log_guardian_event if current_user.is_guardian? && @application.persisted? # OLD LOGIC
        log_application_for_dependent_event if @application.for_dependent? && @application.persisted?
        redirect_to_app(@application)
      else
        # Prepare form for re-rendering
        build_medical_provider_for_form
        initialize_address
        render :new, status: :unprocessable_entity
      end
    end

    # Update an existing application using clean service layer architecture
    # Form handles validation, ApplicationCreator handles persistence
    # @return [void] Redirects to application path or renders form with errors
    def update
      original_status = @application.status

      @form = ApplicationForm.new(
        current_user: current_user,
        application: @application,
        params: params
      )

      return render_update_form_errors unless @form.valid?

      result = Applications::ApplicationCreator.call(@form)

      if result.success?
        notice = determine_update_notice(original_status)
        redirect_to constituent_portal_application_path(result.application), notice: notice
      else
        # Handle service layer errors
        @application = result.application
        result.error_messages.each do |message|
          @application.errors.add(:base, message)
        end

        prepare_medical_provider_for_edit
        render :edit, status: :unprocessable_entity
      end
    end

    # Prepare application attributes with proper formatting
    # @return [Hash] Application attributes ready for update
    def prepare_application_attributes
      # Use filtered_application_params to exclude user/disability fields
      # Merge formatted income
      filtered_application_params.merge(
        annual_income: params[:application][:annual_income]&.gsub(/[^\d.]/, '')
      )
    end

    # Prepare user attributes from params for update operation
    # Assumes cast_boolean_params before_action has already run
    # @return [Hash] User attributes extracted from params
    def prepare_user_attributes_for_update
      # Permit only the user-related attributes from the application params
      # Use .to_h.symbolize_keys to ensure we get a hash with symbol keys
      # Old guardian fields removed, only disability flags remain relevant for user update here.
      params.expect(
        application: %i[hearing_disability
                        vision_disability
                        speech_disability
                        mobility_disability
                        cognition_disability]
      ).to_h.symbolize_keys
    end

    # Log debug information relevant to the update
    # @param _user_attrs [Hash] User attributes being updated (unused)
    def log_update_debug_info(_user_attrs)
      # log_debug "Update - Guardian checkbox value: #{params[:application][:is_guardian].inspect}" # Old field
      # log_debug "Update - Guardian relationship value: #{params[:application][:guardian_relationship].inspect}" # Old field
      log_debug "Before transaction - Application user_id: #{@application.user_id}"
      log_debug "Before transaction - Current user ID: #{current_user.id}"
    end

    # Removed process_application_update - logic moved into update action transaction
    # Removed ensure_user_association_maintained - handled within transaction
    # Removed save_application_with_status_update - replaced with bang version below

    # Handle the result of an application update
    # @param success [Boolean] Whether the update was successful
    # @param original_status [Symbol] The original status of the application
    def handle_application_update_result(success, original_status)
      if success
        # Log dependent application update event if applicable
        log_dependent_application_update_event if @application.for_dependent? && @application.persisted?

        # Determine appropriate notice message
        notice = determine_update_notice(original_status)

        # Always redirect to the application path to ensure guardian can see the result
        # Note that we always redirect to application_path whether it's a guardian-managed update or not
        redirect_to constituent_portal_application_path(@application), notice: notice
      else
        # Prepare form for re-rendering
        log_debug "Application errors: #{@application.errors.full_messages}"
        prepare_medical_provider_for_edit
        render :edit, status: :unprocessable_entity
      end
    end

    # Log an event for updating an application for a dependent
    # @return [void]
    def log_dependent_application_update_event
      return unless @application.managing_guardian && @application.user

      relationship = GuardianRelationship.find_by(
        guardian_id: @application.managing_guardian_id,
        dependent_id: @application.user_id
      )
      # Use the event service to log the application update for a dependent
      service = Applications::EventService.new(@application, user: @application.managing_guardian)
      service.log_dependent_application_update(dependent: @application.user, relationship_type: relationship&.relationship_type)
    end

    # Determine the appropriate notice for an update
    # @param original_status [Symbol] The original status of the application
    # @return [String] The notice message
    def determine_update_notice(original_status)
      # Use the correct enum check method: status_in_progress?
      if @application.status != original_status && @application.status_in_progress?
        'Application submitted successfully!'
      else
        'Application saved successfully.'
      end
    end

    # Prepare medical provider data for edit form
    # @return [void]
    def prepare_medical_provider_for_edit
      @medical_provider = MedicalProviderInfo.new(
        name: find_param_value(:name, :medical_provider) || @application.medical_provider_name,
        phone: find_param_value(:phone, :medical_provider) || @application.medical_provider_phone,
        fax: find_param_value(:fax, :medical_provider) || @application.medical_provider_fax,
        email: find_param_value(:email, :medical_provider) || @application.medical_provider_email
      )
    end

    # Upload documents for proof of income or residency
    # This method handles document uploads and associates them with the appropriate proof types
    # @return [void] Redirects to application path or renders form with errors
    def upload_documents
      @application = current_user.applications.find(params[:id])

      # Early return if no documents were provided
      return handle_missing_documents if params[:documents].blank?

      # Process the document uploads within a transaction
      success = process_document_uploads

      # Handle the result of the upload
      handle_document_upload_result(success)
    end

    # Handle case where no documents were provided
    # @return [void] Redirects to application path with alert
    def handle_missing_documents
      redirect_to constituent_portal_application_path(@application),
                  alert: 'Please select documents to upload.'
    end

    # Process document uploads within a transaction
    # @return [Boolean] Whether all uploads were successful
    def process_document_uploads
      ActiveRecord::Base.transaction do
        # Track which proofs were processed for better user feedback
        processed_proofs = []

        # Process each document type
        params[:documents].each do |document_type, file|
          result = attach_document(document_type, file)
          return false unless result.success?

          processed_proofs << result.type if result.type.present?
        end

        # Save changes and store processed proof info
        finalize_document_uploads(processed_proofs)
        true
      rescue StandardError => e
        log_error('Failed to process document uploads', e)
        false
      end
    end

    # Handle a single document attachment
    # @param document_type [String] The type of document ('income_proof' or 'residency_proof')
    # @param file [ActionDispatch::Http::UploadedFile] The uploaded file
    # @return [ProofResult] Result object with success, type, and message
    def attach_document(document_type, file)
      case document_type
      when 'income_proof'
        attach_proof_document(:income, file)
      when 'residency_proof'
        attach_proof_document(:residency, file)
      else
        # Return failure for unknown document types
        ProofResult.new(success: false, type: nil, message: "Unknown document type: #{document_type}")
      end
    end

    # Attach a specific proof type document
    # @param proof_type [Symbol] The type of proof (:income or :residency)
    # @param file [ActionDispatch::Http::UploadedFile] The file to attach
    # @return [ProofResult] Result with success, type, and optional message
    def attach_proof_document(proof_type, file)
      result = ProofAttachmentService.attach_proof({
                                                     application: @application,
                                                     proof_type: proof_type,
                                                     blob_or_file: file,
                                                     status: :not_reviewed, # Default status for constituent uploads
                                                     admin: nil, # No admin for constituent uploads
                                                     submission_method: :web,
                                                     metadata: { ip_address: request.remote_ip }
                                                   })

      ProofResult.new(
        success: result[:success],
        type: proof_type.to_s,
        message: result[:message]
      )
    end

    # Finalize the document uploads
    # @param processed_proofs [Array<String>] List of proof types that were processed
    # @return [void]
    def finalize_document_uploads(processed_proofs)
      # Reload the application to ensure we have the latest state
      @application.reload.save!

      # Store processed proofs in flash for better user feedback
      flash.now[:processed_proofs] = processed_proofs
    end

    # Handle the result of document uploads
    # @param success [Boolean] Whether the upload was successful
    # @return [void] Redirects or renders with appropriate message
    def handle_document_upload_result(success)
      if success
        redirect_to constituent_portal_application_path(@application),
                    notice: 'Documents uploaded successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def request_review
      @application = current_user.applications.find(params[:id])
      if @application.update(needs_review_since: Time.current)
        User.where(type: 'Users::Administrator').find_each do |admin|
          # Log the audit event
          AuditEventService.log(
            action: 'review_requested',
            actor: current_user,
            auditable: @application,
            metadata: {
              recipient_id: admin.id
            }
          )

          # Send the notification
          NotificationService.create_and_deliver!(
            type: 'review_requested',
            recipient: admin,
            actor: current_user,
            notifiable: @application,
            channel: :email
          )
        end
        redirect_to constituent_portal_application_path(@application),
                    notice: 'Review requested successfully.'
      else
        redirect_to constituent_portal_application_path(@application),
                    alert: 'Unable to request review at this time.'
      end
    end

    def verify
      @application = current_user.applications.find(params[:id])
      render :verify
    end

    def submit
      @application = current_user.applications.find(params[:id])
      if @application.update(submission_params.merge(status: :in_progress))
        ApplicationNotificationsMailer.submission_confirmation(@application).deliver_later
        redirect_to constituent_portal_application_path(@application),
                    notice: 'Application submitted successfully!'
      else
        render :verify, status: :unprocessable_entity
      end
    end

    def resubmit_proof
      @application = current_user.applications.find(params[:id])
      if @application.resubmit_proof!
        redirect_to constituent_portal_application_path(@application),
                    notice: 'Proof resubmitted successfully'
      else
        redirect_to constituent_portal_application_path(@application),
                    alert: 'Failed to resubmit proof'
      end
    end

    # Request a training session for an approved application
    # This method validates eligibility, checks quota limits, and creates
    # necessary notifications for administrators
    # @return [void] Redirects to dashboard with appropriate message
    def request_training
      @application = current_user.applications.find(params[:id])

      # First check if the application is eligible for training
      return unless validate_application_for_training

      # Then check if the user has reached their training session limit
      return unless check_training_session_limit

      # Create notifications for administrators
      create_training_request_notifications

      # Record the training request activity if applicable
      log_training_request

      # Finally, redirect with success message
      redirect_with_notice(constituent_portal_dashboard_path,
                           'Training request submitted. An administrator will contact you to schedule your session.')
    end

    # Validate that the application is eligible for training (approved status)
    # @return [Boolean] true if eligible, false otherwise (with redirect)
    def validate_application_for_training
      unless @application.status_approved?
        redirect_with_alert(constituent_portal_dashboard_path,
                            'Only approved applications are eligible for training.')
        return false
      end

      true
    end

    # Check if the user has reached their training session limit
    # @return [Boolean] true if limit not reached, false otherwise (with redirect)
    def check_training_session_limit
      max_training_sessions = Policy.get('max_training_sessions') || 3

      if @application.training_sessions.count >= max_training_sessions
        redirect_with_alert(constituent_portal_dashboard_path,
                            'You have used all of your available training sessions.')
        return false
      end

      true
    end

    # Create notifications for all administrators about the training request
    # @return [void]
    def create_training_request_notifications
      User.where(type: 'Users::Administrator').find_each do |admin|
        # Log the audit event
        AuditEventService.log(
          action: 'training_requested',
          actor: current_user,
          auditable: @application,
          metadata: {
            recipient_id: admin.id,
            constituent_id: current_user.id,
            constituent_name: current_user.full_name
          }
        )

        # Send the notification
        NotificationService.create_and_deliver!(
          type: 'training_requested',
          recipient: admin,
          actor: current_user,
          notifiable: @application,
          metadata: {
            application_id: @application.id,
            constituent_id: current_user.id,
            constituent_name: current_user.full_name
          },
          channel: :email
        )
      end
    end

    # Log the training request activity if the Activity class is available
    # @return [void]
    def log_training_request
      # Log as an audit event
      AuditEventService.log(
        action: 'training_session_requested',
        actor: current_user,
        auditable: @application,
        metadata: {
          constituent_id: current_user.id
        }
      )
    end

    # Autosave a single field for an application
    # This action handles AJAX requests to save individual fields as users navigate the form
    # @return [JSON] JSON response with success status, errors, and application ID if new
    def autosave_field
      result = process_autosave_request
      render_autosave_response(result)
    rescue ActiveRecord::RecordNotFound
      render_autosave_error('Application not found', :not_found)
    rescue StandardError => e
      log_error("Autosave error: #{e.message}", e)
      render_autosave_error('An error occurred during autosave', :internal_server_error)
    end

    # Return FPL thresholds for JavaScript form calculations
    # @return [JSON] JSON response with thresholds and modifier
    def fpl_thresholds
      thresholds = {}
      (1..8).each do |size|
        policy = Policy.find_by(key: "fpl_#{size}_person")
        thresholds[size.to_s] = policy&.value.to_i
      end
      modifier = Policy.find_by(key: 'fpl_modifier_percentage')&.value&.to_i || 400
      render json: { thresholds: thresholds, modifier: modifier }
    end

    private

    # Process the autosave request and return result
    # @return [Hash] Result with success status and data
    def process_autosave_request
      field_name = params[:field_name]
      field_value = params[:field_value]

      return autosave_error_result('Field name is required') if field_name.blank?
      return autosave_error_result('File uploads are not supported for autosave', field_name) if file_field?(field_name)

      initialize_application_for_autosave
      save_autosave_field(field_name, field_value)
    end

    # Check if the field is a file upload field
    # @param field_name [String] The field name to check
    # @return [Boolean] Whether this is a file field
    def file_field?(field_name)
      field_name.ends_with?('proof]') || field_name.include?('file')
    end

    # Initialize or find application for autosave
    # @return [void]
    def initialize_application_for_autosave
      @application = if params[:id].present?
                       find_existing_application_for_autosave
                     else
                       create_new_application_for_autosave
                     end
    end

    # Find existing application for autosave
    # @return [Application] The found or initialized application
    def find_existing_application_for_autosave
      current_user.applications.find_or_initialize_by(id: params[:id]) do |app|
        app.status = :draft
        app.application_date = Time.current
        app.submission_method = :online
        app.application_type ||= :new
      end
    end

    # Create new application for autosave
    # @return [Application] The new application
    def create_new_application_for_autosave
      current_user.applications.new(
        status: :draft,
        application_date: Time.current,
        submission_method: :online,
        application_type: :new
      )
    end

    # Save a field during autosave
    # @param field_name [String] The field name from the form
    # @param field_value [String] The field value to save
    # @return [Hash] Result with success status and data
    def save_autosave_field(field_name, field_value)
      attribute_name = extract_attribute_name(field_name)
      target_model, actual_attribute = determine_target_model_and_attribute(attribute_name)

      log_debug("Autosave - attribute: #{attribute_name}, target: #{target_model}")

      result = if target_model == :user
                 autosave_user_field(actual_attribute, field_value)
               else
                 autosave_application_field(actual_attribute, field_value)
               end

      result[:success] ? autosave_success_result : result
    end

    # Create a success result for autosave
    # @return [Hash] Success result
    def autosave_success_result
      { success: true, application_id: @application.id, message: 'Field saved successfully' }
    end

    # Create an error result for autosave
    # @param message [String] The error message
    # @param field_name [String, nil] Optional field name for specific field errors
    # @return [Hash] Error result
    def autosave_error_result(message, field_name = nil)
      errors = field_name ? { field_name => [message] } : { base: [message] }
      { success: false, errors: errors }
    end

    # Render the autosave response
    # @param result [Hash] The result to render
    # @return [void]
    def render_autosave_response(result)
      if result[:success]
        render json: { 
          success: true, 
          applicationId: result[:application_id], 
          message: result[:message] 
        }, status: :ok
      else
        render json: { success: false, errors: result[:errors] }, status: :unprocessable_entity
      end
    end

    # Render an autosave error response
    # @param message [String] The error message
    # @param status [Symbol] The HTTP status symbol
    # @return [void]
    def render_autosave_error(message, status)
      render json: { success: false, errors: { base: [message] } }, status: status
    end

    # Extract the attribute name from the form field name
    # @param field_name [String] The form field name (e.g., "application[household_size]")
    # @return [String] The attribute name (e.g., "household_size")
    def extract_attribute_name(field_name)
      # Handle nested medical provider attributes in application params
      if field_name.start_with?('application[') && field_name.include?('medical_provider_attributes') &&
         field_name =~ /application\[medical_provider_attributes\]\[([^\]]+)\]/
        return "medical_provider_#{::Regexp.last_match(1)}"
      end

      # Strip off the "application[" prefix and the "]" suffix for standard fields
      return field_name[12..-2] if field_name.start_with?('application[') && field_name.end_with?(']')

      # Handle standalone medical provider attributes
      return "medical_provider_#{::Regexp.last_match(1)}" if field_name =~ /medical_provider_attributes\[([^\]]+)\]/

      # Default case
      field_name
    end

    # Determine which model a field belongs to and its actual attribute name
    # @param attribute_name [String] The extracted attribute name
    # @return [Array<Symbol, String>] The target model (:user or :application) and the actual attribute name
    def determine_target_model_and_attribute(attribute_name)
      user_fields = %w[hearing_disability vision_disability speech_disability
                       mobility_disability cognition_disability] # Removed is_guardian, guardian_relationship

      # Fields that should be ignored for autosave
      ignored_fields = %w[physical_address_1 physical_address_2 city state zip_code
                          residency_proof income_proof]

      if user_fields.include?(attribute_name)
        [:user, attribute_name]
      elsif ignored_fields.include?(attribute_name)
        [:ignored, attribute_name]
      else
        [:application, attribute_name]
      end
    end

    # Save a user field with appropriate validation
    # @param attribute [String] The attribute name
    # @param value [String, Boolean] The value to save
    # @return [Hash] Result with success flag and any errors
    def autosave_user_field(attribute, value)
      # Cast value if it's a boolean field
      if %w[hearing_disability vision_disability speech_disability mobility_disability
            cognition_disability].include?(attribute) # Removed is_guardian
        value = to_boolean(value)
      end

      # Removed special validation for guardian_relationship as it's deprecated

      # Update the attribute directly to bypass validations
      # Ensure this updates the correct user (applicant_user if application is for dependent)
      # For autosave, it's tricky as @application.user might not be set if it's a new application.
      # However, user-specific fields like disabilities should ideally be updated on the current_user
      # if the application context isn't fully established for a dependent yet.
      # This part of autosave might need more context if it's intended to update a dependent's user record
      # before the main create/update action. For now, assume it updates current_user.
      current_user.update_column(attribute, value)

      # Update last visited step if application exists
      @application.update_column(:last_visited_step, attribute) if @application.persisted?

      { success: true }
    rescue StandardError => e
      log_error("Error autosaving user field #{attribute}: #{e.message}", e)
      { success: false, errors: { "application[#{attribute}]" => [e.message] } }
    end

    # Save an application field with appropriate validation
    # @param attribute [String] The attribute name
    # @param value [String, Boolean] The value to save
    # @return [Hash] Result with success flag and any errors
    def autosave_application_field(attribute, value)
      return handle_ignored_attribute(attribute) if attribute == :ignored

      validation_result = validate_application_field_value(attribute, value)
      return validation_result unless validation_result[:success]

      save_result = save_application_field_value(attribute, value)
      return save_result unless save_result[:success]

      update_last_visited_step(attribute)
      { success: true }
    rescue StandardError => e
      log_error("Error autosaving application field #{attribute}: #{e.message}", e)
      { success: false, errors: { "application[#{attribute}]" => [e.message] } }
    end

    # Handle ignored attributes that cannot be autosaved
    # @param attribute [String] The attribute name
    # @return [Hash] Error result
    def handle_ignored_attribute(attribute)
      { success: false, errors: { "application[#{attribute}]" => ['This field cannot be autosaved'] } }
    end

    # Validate the value for an application field
    # @param attribute [String] The attribute name
    # @param value [String, Boolean] The value to validate
    # @return [Hash] Validation result
    def validate_application_field_value(attribute, value)
      case attribute
      when 'annual_income'
        return { success: false, errors: { 'application[annual_income]' => ['Must be a valid number'] } } unless value.to_s.match?(/\A\d+(\.\d+)?\z/)
      when 'household_size'
        return { success: false, errors: { 'application[household_size]' => ['Must be a valid integer'] } } unless value.to_s.match?(/\A\d+\z/)
      end

      { success: true }
    end

    # Save the application field value
    # @param attribute [String] The attribute name
    # @param value [String, Boolean] The value to save
    # @return [Hash] Save result
    def save_application_field_value(attribute, value)
      # Cast value if it's a boolean field
      processed_value = %w[maryland_resident self_certify_disability].include?(attribute) ? to_boolean(value) : value

      begin
        @application.assign_attributes(attribute => processed_value)
      rescue ActiveRecord::UnknownAttributeError
        return { success: false, errors: { "application[#{attribute}]" => ['This field cannot be autosaved'] } }
      end

      # Validate only this attribute
      @application.valid?

      return { success: false, errors: { "application[#{attribute}]" => @application.errors[attribute] } } if @application.errors[attribute].any?

      # Save without validations since we're just saving one field at a time
      @application.save(validate: false)
      { success: true }
    end

    # Update the last visited step for the application
    # @param attribute [String] The attribute name
    # @return [void]
    def update_last_visited_step(attribute)
      @application.update_column(:last_visited_step, attribute)
    end

    # Save application with potential status update (bang version)
    # @param is_submission [Boolean] Whether this is a submission
    # @return [void] Raises ActiveRecord::RecordInvalid on failure
    def save_application_with_status_update!(is_submission)
      # Assign status based on submission flag *before* saving
      # Use the correct enum check method: status_draft?
      if is_submission && @application.status_draft?
        log_debug 'Setting application status to in_progress for submission'
        @application.status = :in_progress
      end
      @application.save! # Use bang method
    end

    # Removed validate_disability_selection_for_update - logic moved into transaction

    # Helper to filter out disability attributes
    # @param attrs [Hash] Original user attributes hash
    # @return [Hash] Attributes hash without disability keys
    def user_attrs_without_disabilities(attrs)
      attrs.except(
        :hearing_disability, :vision_disability, :speech_disability,
        :mobility_disability, :cognition_disability
      )
    end

    # Update user attributes (simplified - raises error on failure)
    # @param attrs [Hash] The attributes to update
    # @return [void] Raises ActiveRecord::RecordInvalid on failure
    def update_user_attributes(attrs)
      processed_attrs = process_user_attributes(attrs)
      ensure_consistent_constituent_type(processed_attrs)
      current_user.update!(processed_attrs) # Use bang method
      current_user.reload # Reload after successful update
      log_user_update_details
    end

    # Save application and create event log (bang version)
    # @return [void] Raises ActiveRecord::RecordInvalid on failure
    def save_application_with_event_log!
      @application.save! # Use bang method

      Event.create!(
        user: current_user,
        action: 'application_created',
        metadata: {
          application_id: @application.id,
          submission_method: 'online',
          initial_status: @application.status,
          timestamp: Time.current.iso8601
        }
      )
    end

    def set_initial_application_attributes(app, is_submission)
      app.status = is_submission ? :in_progress : :draft
      app.application_date = Time.current
      app.submission_method = :online
      app.application_type ||= :new
    end

    def extract_user_attributes(p)
      # Only extract disability flags. Guardian status is now managed by GuardianRelationship.
      {
        hearing_disability: ['1', true].include?(p.dig(:application, :hearing_disability)),
        vision_disability: ['1', true].include?(p.dig(:application, :vision_disability)),
        speech_disability: ['1', true].include?(p.dig(:application, :speech_disability)),
        mobility_disability: ['1', true].include?(p.dig(:application, :mobility_disability)),
        cognition_disability: ['1', true].include?(p.dig(:application, :cognition_disability))
        # Address fields removed - handle profile updates separately
      }
    end

    def extract_address_attributes(p)
      # Extract address fields from application params for user update
      {
        physical_address_1: p.dig(:application, :physical_address_1),
        physical_address_2: p.dig(:application, :physical_address_2),
        city: p.dig(:application, :city),
        state: p.dig(:application, :state),
        zip_code: p.dig(:application, :zip_code)
      }.compact # Remove nil values
    end

    def debug_application_info(app, p)
      # Rails.logger.debug { "Guardian checkbox value: #{p[:application][:is_guardian].inspect}" } # Old field
      # Rails.logger.debug { "Guardian relationship value: #{p[:application][:guardian_relationship].inspect}" } # Old field
      Rails.logger.debug { "Application attributes before save: #{app.attributes.inspect}" }
      Rails.logger.debug { "Medical provider attributes: #{p.dig(:application, :medical_provider_attributes).inspect}" }
      Rails.logger.debug { "Application valid? #{app.valid?}" }
      Rails.logger.debug { "Application errors: #{app.errors.full_messages}" } if app.invalid?
    end

    def log_application_for_dependent_event
      return unless @application.managing_guardian && @application.user

      relationship = GuardianRelationship.find_by(
        guardian_id: @application.managing_guardian_id,
        dependent_id: @application.user_id
      )
      # Use the event service to log the application submission for a dependent
      service = Applications::EventService.new(@application, user: @application.managing_guardian)
      service.log_submission_for_dependent(dependent: @application.user, relationship_type: relationship&.relationship_type)
    end

    def redirect_to_app(app)
      notice = params[:submit_application] ? 'Application submitted successfully!' : 'Application saved as draft.'
      redirect_to constituent_portal_application_path(app), notice: notice
    end

    def build_medical_provider_for_form
      @application.medical_provider_attributes ||= {} if @application
      @medical_provider = MedicalProviderInfo.new(
        name: find_param_value(:name, :medical_provider),
        phone: find_param_value(:phone, :medical_provider),
        fax: find_param_value(:fax, :medical_provider),
        email: find_param_value(:email, :medical_provider)
      )
    end

    # Helper method to find a parameter value from various possible locations
    # @param field [Symbol] The field name to look for
    # @param param_type [Symbol] The type of parameter (e.g. :medical_provider)
    # @return [String, nil] The found value or nil
    def find_param_value(field, param_type)
      params.dig(param_type, field) ||
        params.dig(:application, param_type, field) ||
        params.dig(:application, :"#{param_type}_#{field}") ||
        @application&.send("#{param_type}_#{field}")
    end

    def filtered_application_params
      # Exclude medical_provider_attributes as they are handled separately
      application_params.except(
        :medical_provider_attributes,
        # :is_guardian, # Deprecated from direct user update here
        # :guardian_relationship, # Deprecated from direct user update here
        :hearing_disability,
        :vision_disability,
        :speech_disability,
        :mobility_disability,
        :cognition_disability,
        # Also exclude address fields that should only update the User model
        :physical_address_1,
        :physical_address_2,
        :city,
        :state,
        :zip_code
      )
    end

    def submission_params
      params.expect(
        application: %i[terms_accepted
                        information_verified
                        medical_release_authorized]
      )
    end

    # Find the application with proper STI type handling
    # This method tries multiple approaches to handle potential type mismatches
    # between Constituent and Users::Constituent
    # @return [Application, nil] The found application or nil (with redirect)
    def set_application
      # Try primary approach first - using association
      @application = find_application_by_standard_query

      # If that fails, try alternative approach to handle STI type issues
      @application = find_application_by_flexible_query if @application.nil?

      # If we still couldn't find it, redirect
      handle_application_not_found if @application.nil?
    end

    # Find application using the standard association
    # @return [Application, nil] The found application or nil
    def find_application_by_standard_query
      # Include both:
      # 1. Applications where the user is the direct owner/applicant
      # 2. Applications where the user is the managing guardian
      Application.where(id: params[:id])
                 .where(
                   'user_id = :uid
                   OR managing_guardian_id = :uid
                   OR EXISTS (
                       SELECT 1 FROM guardian_relationships gr
                       WHERE gr.guardian_id = :uid
                         AND gr.dependent_id = applications.user_id
                   )',
                   uid: current_user.id
                 )
                 .first
    end

    # Find application using a more flexible query to work around STI issues
    # @return [Application, nil] The found application or nil
    def find_application_by_flexible_query
      # First try to find by user_id (when user is the applicant)
      app = Application.find_by(id: params[:id], user_id: current_user.id)

      # If not found, try to find by managing_guardian_id (when user is the guardian)
      app ||= Application.find_by(id: params[:id], managing_guardian_id: current_user.id)

      # Return the application found by either method
      app
    end

    # Handle the case when application is not found
    # @return [void] Redirects to dashboard with alert
    def handle_application_not_found
      log_error("Application #{params[:id]} not found for user #{current_user.id}")
      redirect_with_alert(constituent_portal_dashboard_path, 'Application not found')
    end

    def ensure_editable
      return if @application.status_draft?

      redirect_to constituent_portal_application_path(@application),
                  alert: 'This application has already been submitted and cannot be edited.'
    end

    def application_params
      params.expect(
        application: [:user_id, # Allow user_id for selecting dependent
                      :application_type,
                      :submission_method,
                      :maryland_resident,
                      :annual_income,
                      :household_size,
                      :self_certify_disability,
                      :residency_proof,
                      :income_proof,
                      :income_details,
                      :residency_details,
                      :terms_accepted,
                      :information_verified,
                      :medical_release_authorized,
                      :alternate_contact_name,
                      :alternate_contact_phone,
                      :alternate_contact_email,
                      # :is_guardian, # Deprecated user fields, not application fields
                      # :guardian_relationship, # Deprecated user fields, not application fields
                      :hearing_disability, # These are user attributes, but often submitted with app
                      :vision_disability,
                      :speech_disability,
                      :mobility_disability,
                      :cognition_disability,
                      :physical_address_1,
                      :physical_address_2,
                      :city,
                      :state,
                      :zip_code,
                      # Permit nested attributes directly
                      { medical_provider_attributes: %i[name phone fax email] }]
      )
      # Remove the key transformation logic
      # Return params with nested attributes if present
    end

    def user_params
      params.expect(application: %i[hearing_disability vision_disability
                                    speech_disability mobility_disability
                                    cognition_disability]).transform_values { |v| to_boolean(v) }
    end

    # Strong params for the verify step
    def verification_params
      params
        .expect(application: %i[terms_accepted information_verified medical_release_authorized])
    end

    # Extract and prefix nested medical_provider attributes (if present)
    def medical_provider_params
      if params.dig(:application, :medical_provider_attributes).present?
        mp = params
             .require(:application)
             .require(:medical_provider_attributes)
             .permit(:name, :phone, :fax, :email)

        # Use transform_keys with symbol interpolation
        mp.transform_keys { |key| :"medical_provider_#{key}" }
      else
        {}
      end
    end

    def require_constituent!
      return if current_user&.constituent?

      redirect_to root_path, alert: 'Access denied. Constituent-only area.'
    end

    # Process user attributes with type casting
    # @param attrs [Hash] Raw attributes from params
    # @return [Hash] Processed attributes with proper types
    def process_user_attributes(attrs)
      processed_attrs = {}

      # Process disability fields
      process_disability_attributes(attrs, processed_attrs)

      # Process address fields
      process_address_attributes(attrs, processed_attrs)

      log_debug("Processed attributes: #{processed_attrs.inspect}")
      processed_attrs
    end

    # Process disability attributes for user
    # @param attrs [Hash] Raw attributes from params
    # @param processed_attrs [Hash] Hash to add processed attributes to
    def process_disability_attributes(attrs, processed_attrs)
      %i[hearing_disability vision_disability speech_disability
         mobility_disability cognition_disability].each do |attr|
        processed_attrs[attr] = to_boolean(attrs[attr])
      end
    end

    # Process address attributes for user
    # @param _attrs [Hash] Raw attributes from params (unused)
    # @param _processed_attrs [Hash] Hash to add processed attributes to (unused)
    def process_address_attributes(_attrs, _processed_attrs)
      # No-op: Address updates should be handled separately from application creation/update
    end

    # Ensure the user has the correct STI type for associations
    # @param processed_attrs [Hash] Attributes hash to update with type
    def ensure_consistent_constituent_type(processed_attrs)
      # IMPORTANT: Set type to "Users::Constituent" to match Application model's association
      # This fixes the STI type mismatch between Constituent and Users::Constituent
      processed_attrs[:type] = 'Users::Constituent'
    end

    # Save user with proper error handling and logging
    # @param processed_attrs [Hash] Attributes to save
    # @return [Boolean] Whether the save was successful
    def save_user_with_error_handling(processed_attrs)
      # Use update! for reliability and consistent validation
      current_user.update!(processed_attrs)

      # Ensure the user is fully saved before proceeding
      current_user.save!

      # Reload to ensure we have the latest state of the user
      current_user.reload

      # Log detailed information for debugging
      log_user_update_details

      true
    rescue StandardError => e
      log_error('User save failed', e)
      false
    end

    # Log detailed information after user update
    def log_user_update_details
      log_debug("User type after update: #{current_user.type}")
      log_debug("User is a constituent? #{current_user.constituent?}")
      log_debug('User disability status after update: ' \
                "hearing=#{current_user.hearing_disability}, " \
                "vision=#{current_user.vision_disability}, " \
                "speech=#{current_user.speech_disability}, " \
                "mobility=#{current_user.mobility_disability}, " \
                "cognition=#{current_user.cognition_disability}")
      log_debug("User address after update: #{current_user.physical_address_1}, " \
                "#{current_user.city}, #{current_user.state} #{current_user.zip_code}")
      log_debug("User has_disability_selected? returns: #{current_user.has_disability_selected?}")
    end

    # NOTE: cast_boolean_params is now provided by the ParamCasting concern

    def initialize_address
      # Use dig with both potential key formats to handle inconsistency
      addr1 = params.dig(:application,
                         :physical_address1) || params.dig(:application, :physical_address_1) || current_user.physical_address_1
      addr2 = params.dig(:application,
                         :physical_address2) || params.dig(:application, :physical_address_2) || current_user.physical_address_2
      city_val = params.dig(:application, :city) || current_user.city
      state_val = params.dig(:application, :state) || current_user.state
      zip_val = params.dig(:application, :zip_code) || current_user.zip_code # Corrected: Use zip_val below

      @address = Address.new(
        physical_address_1: addr1,
        physical_address_2: addr2,
        city: city_val,
        state: state_val,
        zip_code: zip_val
      )
    end

    # Set paper application context for tests to bypass proof validations
    # @return [void]
    def set_paper_application_context
      Current.paper_context = true
      log_debug('Paper application context set for tests - bypassing proof validations')
    end
  end
end
