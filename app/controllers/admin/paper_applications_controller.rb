# frozen_string_literal: true

module Admin
  class PaperApplicationsController < Admin::BaseController
    before_action :cast_boolean_params, only: %i[create update]

    USER_BASE_FIELDS = %i[
      first_name last_name email phone
      physical_address_1 physical_address_2 city state zip_code
      communication_preference
    ].freeze

    USER_DISABILITY_FIELDS = %i[
      self_certify_disability hearing_disability vision_disability speech_disability
      mobility_disability cognition_disability
    ].freeze

    DEPENDENT_BASE_FIELDS = %i[
      first_name last_name date_of_birth
      physical_address_1 physical_address_2 city state zip_code
    ].freeze

    APPLICATION_FIELDS = %i[
      household_size annual_income maryland_resident self_certify_disability
      medical_provider_name medical_provider_phone medical_provider_fax
      medical_provider_email terms_accepted information_verified
      medical_release_authorized
      alternate_contact_name alternate_contact_phone alternate_contact_email
    ].freeze

    def new
      @paper_application = {
        application: Application.new,
        guardian_attributes: Users::Constituent.new, # Ensure this key exists for fields_for
        dependent_attributes: {},
        applicant_attributes: {},
        constituent: Constituent.new
      }
      # Ensure guardian_attributes is an empty hash if not already set,
      # or build from an existing model if @paper_application was a real model instance.
      # For simplicity with the current hash structure:

      @show_create_guardian_form = params[:show_create_guardian_form].present?
    end

    def create
      log_file_and_form_params
      service_params = paper_application_processing_params # Use the new method
      Rails.logger.debug { "Service params before service call: #{service_params.inspect}" }

      service = Applications::PaperApplicationService.new(
        params: service_params,
        admin: current_user
      )

      if service.create
        redirect_to admin_application_path(service.application),
                    notice: generate_success_message(service.application)
      else
        handle_service_failure(service)
      end
    end

    def update
      log_file_and_form_params
      service_params = paper_application_processing_params # Use the new method
      Rails.logger.debug { "Service params for update: #{service_params.inspect}" }

      application = Application.find(params[:id])
      # ... (logging from original update can be kept or removed as needed)

      service = Applications::PaperApplicationService.new(
        params: service_params,
        admin: current_user
      )

      if service.update(application)
        redirect_to admin_application_path(application),
                    notice: generate_success_message(application)
      else
        handle_service_failure(service, application)
      end
    end

    def fpl_thresholds
      thresholds = {}
      (1..8).each do |size|
        thresholds[size] = Policy.get("fpl_#{size}_person").to_i
      end
      modifier = Policy.get('fpl_modifier_percentage').to_i
      render json: { thresholds: thresholds, modifier: modifier }
    end

    def send_rejection_notification
      # This method seems out of scope for the current refactor of params,
      # but ensure it still works or adapt if constituent_params structure changes impact it.
      # For now, assuming it uses flat params from the form directly.
      constituent_params_for_notification = build_constituent_params_for_notification
      notification_params = build_notification_params

      communication_preference = params[:notification_method] || params[:communication_preference]

      if communication_preference == 'email'
        ApplicationNotificationsMailer.income_threshold_exceeded(constituent_params_for_notification, notification_params)
                                      .deliver_later
        flash[:notice] = 'Rejection notification has been sent.'
      elsif communication_preference == 'letter'
        flash[:notice] = 'Rejection letter has been queued for printing.' # Assuming a letter service exists
      end
      redirect_to admin_applications_path
    end

    private

    def handle_service_failure(service, existing_application = nil)
      if service.errors.any?
        error_message = service.errors.join('; ')
        Rails.logger.error "Paper application operation failed: #{error_message}"
        flash.now[:alert] = error_message
      else
        Rails.logger.error 'Paper application operation failed with no specific service errors.'
        flash.now[:alert] = 'An unexpected error occurred.'
      end

      # Repopulate @paper_application for the form
      # The service should ideally return the objects it was working with, even on failure.
      @paper_application = {
        application: service.application || existing_application || Application.new,
        constituent: service.constituent || existing_application&.user || Constituent.new,
        guardian_user_for_app: service.guardian_user_for_app, # For repopulating guardian fields
        # Pass back the original params to help repopulate complex forms
        submitted_params: params.to_unsafe_h.slice(:applicant_type, :relationship_type, :guardian_id, :dependent_id,
                                                   :guardian_attributes, :dependent_attributes, :applicant_attributes,
                                                   :application, :constituent)
      }
      render (existing_application ? :edit : :new), status: :unprocessable_entity
    end

    def log_file_and_form_params
      Rails.logger.debug 'CONTROLLER - Params received:'
      Rails.logger.debug { params.inspect }
      Rails.logger.debug 'CONTROLLER - File params present:'
      Rails.logger.debug { "income_proof present: #{params[:income_proof].present?}" }
      Rails.logger.debug { "residency_proof present: #{params[:residency_proof].present?}" }
      return unless params[:income_proof].present? && params[:income_proof].respond_to?(:original_filename)

      Rails.logger.debug { "income_proof filename: #{params[:income_proof].original_filename}" }
    end

    def generate_success_message(application)
      # ... (original generate_success_message logic)
      if application.proof_reviews.where(status: :rejected).any?
        rejected_proofs = []
        rejected_proofs << 'income' if application.income_proof_status_rejected?
        rejected_proofs << 'residency' if application.residency_proof_status_rejected?

        if rejected_proofs.any?
          message = "Paper application successfully submitted with #{rejected_proofs.length} rejected "
          message += rejected_proofs.length == 1 ? 'proof' : 'proofs'
          message += ": #{rejected_proofs.join(' and ')}. Notifications will be sent."
          return message
        end
      end
      'Paper application successfully submitted.'
    end

    # Main method to construct parameters for the PaperApplicationService
    def paper_application_processing_params
      # Start with top-level permitted scalar values
      # Infer applicant_type if guardian_id is present, as the radio buttons might be hidden
      current_applicant_type = params[:applicant_type]
      if params[:guardian_id].present? && params[:dependent_attributes].present? && params.require(:dependent_attributes).permit(:first_name).present?
        current_applicant_type = 'dependent'
      end

      service_params = params.permit(:relationship_type, :guardian_id, :dependent_id, :use_guardian_address, :use_guardian_email)
                             .to_h.with_indifferent_access
      service_params[:applicant_type] = current_applicant_type # Add inferred or passed applicant_type

      # Application attributes - initialize with permitted ones
      service_params[:application] = permitted_application_attributes if params[:application].present?
      service_params[:application] ||= {} # Ensure it's a hash

      # Applicant disability attributes (from applicant_attributes section of the form)
      all_applicant_attrs = permitted_applicant_disability_attributes # This includes self_certify_disability and specific flags

      # Separate self_certify_disability for the Application model
      if all_applicant_attrs.key?(:self_certify_disability)
        service_params[:application][:self_certify_disability] = all_applicant_attrs.delete(:self_certify_disability)
      end
      # Remaining attrs in all_applicant_attrs are the specific disability flags for the User model

      # `all_applicant_attrs` now only contains specific disability flags for the User model (e.g. hearing_disability)

      if service_params[:applicant_type] == 'dependent'
        # The APPLICANT is the DEPENDENT. Their attributes are prepared for the :constituent key for the service.
        # Ensure dependent_attributes are present and permitted
        dep_attrs = {}
        dep_attrs = permitted_dependent_attributes if params[:dependent_attributes].present?
        service_params[:constituent] = dep_attrs.deep_merge(all_applicant_attrs) # Populate :constituent with dependent's data

        # Handle the Guardian separately
        if service_params[:guardian_id].present? # Check service_params for guardian_id
          # guardian_id is already in service_params if present and permitted at the start
        elsif params[:guardian_attributes].present?
          # New guardian to be created
          service_params[:new_guardian_attributes] = permitted_guardian_attributes
        end
        # Remove original keys if they might conflict or be misinterpreted by the service
        service_params.delete(:dependent_attributes)
        service_params.delete(:guardian_attributes)

      else # Self-application (applicant_type == 'guardian' or legacy/unspecified)
        # The APPLICANT is the self-applying adult. Their attributes go into :constituent.
        # Data could be from params[:constituent] (from _self_application_fields rendered on the form)
        # or params[:guardian_attributes] (if "Create New Guardian" form was used for a self-applicant)

        # Prioritize params[:constituent] if its fields (like first_name) are actually filled.
        service_params[:constituent] = if params[:constituent].present? && params.require(:constituent).permit(:first_name).present?
                                         permitted_constituent_basic_attributes.deep_merge(all_applicant_attrs)
                                       elsif params[:guardian_attributes].present? # Check if creating a new user who is the self-applicant
                                         # This implies the "Create New Guardian" form was filled, and it's a self-application.
                                         # So, these guardian_attributes are for the applicant.
                                         permitted_guardian_attributes.deep_merge(all_applicant_attrs)
                                       else
                                         # Fallback: ensure only disability flags are passed if other fields are empty
                                         all_applicant_attrs
                                       end
        # No separate guardian in self-application; the applicant IS the guardian.
        # Clear out other potentially confusing keys.
        service_params.delete(:dependent_attributes)
        service_params.delete(:guardian_attributes) # Data was merged into :constituent if applicable
      end

      add_proof_params(service_params)
      Rails.logger.debug { "Final service params: #{service_params.inspect}" }
      service_params
    end

    def permitted_guardian_attributes
      params.require(:guardian_attributes).permit(*USER_BASE_FIELDS, *USER_DISABILITY_FIELDS)
            .to_h.with_indifferent_access
    end

    def permitted_dependent_attributes
      # Permit base user fields, dependent-specific fields, and disability flags for dependent creation
      params.require(:dependent_attributes)
            .permit(*USER_BASE_FIELDS, *DEPENDENT_BASE_FIELDS, *USER_DISABILITY_FIELDS)
            .to_h.with_indifferent_access
    end

    def permitted_applicant_disability_attributes
      if params[:applicant_attributes].present?
        params.require(:applicant_attributes).permit(*USER_DISABILITY_FIELDS).to_h.with_indifferent_access
      else
        {}
      end
    end

    def permitted_application_attributes
      params.require(:application).permit(*APPLICATION_FIELDS).to_h.with_indifferent_access
    end

    # For the old :constituent path, permit base fields + disability fields
    def permitted_constituent_basic_attributes
      params.require(:constituent).permit(*USER_BASE_FIELDS, *USER_DISABILITY_FIELDS)
            .to_h.with_indifferent_access
    end

    def add_proof_params(service_params)
      # ... (original add_proof_params logic)
      %w[income residency].each do |type|
        action_key = "#{type}_proof_action"
        service_params[action_key] = params[action_key]

        file_key = "#{type}_proof"
        service_params[file_key] = params[file_key] if params[file_key].present?

        signed_id_key = "#{type}_proof_signed_id"
        service_params[signed_id_key] = params[signed_id_key] if params[signed_id_key].present?

        service_params["#{type}_proof_rejection_reason"] = params["#{type}_proof_rejection_reason"]
        service_params["#{type}_proof_rejection_notes"] = params["#{type}_proof_rejection_notes"]
      end
    end

    def build_constituent_params_for_notification
      # Simplified for notification, might need adjustment based on actual form fields for notification
      params.permit(:first_name, :last_name, :email, :phone).to_h
    end

    def build_notification_params
      params.permit(:household_size, :annual_income, :communication_preference, :additional_notes).to_h
    end

    def cast_boolean_params
      # Cast for application attributes
      if params[:application].present?
        cast_boolean_for(params[:application], APPLICATION_FIELDS.select do |f|
          f.to_s.match?(/disability$|resident$|accepted$|verified$|authorized$/)
        end)
      end

      # Cast for disability attributes within nested structures
      cast_boolean_for(params[:applicant_attributes], USER_DISABILITY_FIELDS) if params[:applicant_attributes].present?
      cast_boolean_for(params[:guardian_attributes], USER_DISABILITY_FIELDS) if params[:guardian_attributes].present?
      cast_boolean_for(params[:dependent_attributes], USER_DISABILITY_FIELDS) if params[:dependent_attributes].present?

      # Cast for fallback constituent structure
      cast_boolean_for(params[:constituent], USER_DISABILITY_FIELDS) if params[:constituent].present?
    end

    def cast_boolean_for(hash, fields)
      return unless hash.is_a?(ActionController::Parameters) || hash.is_a?(Hash)

      fields.each do |field|
        field_sym = field.to_sym
        next unless hash.key?(field_sym)

        value = hash[field_sym]
        # Handle array_to_hidden_checkboxes_workaround if it's still in use
        value = value.last if value.is_a?(Array) && value.size == 2 && value.first.blank?
        hash[field_sym] = ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
