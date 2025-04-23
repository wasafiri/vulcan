# frozen_string_literal: true

module Admin
  class PaperApplicationsController < Admin::BaseController
    before_action :cast_boolean_params, only: [:create]

    def new
      @paper_application = {
        application: Application.new,
        constituent: Constituent.new
      }
    end

    def create
      log_file_and_form_params
      service_params = paper_application_params
      Rails.logger.debug { "Service params before service call: #{service_params.keys.inspect}" }

      service = Applications::PaperApplicationService.new(
        params: service_params,
        admin: current_user
      )

      if service.create
        redirect_to admin_application_path(service.application),
                    notice: generate_success_message(service.application)
      else
        flash.now[:alert] = service.errors.first if service.errors.any?
        @paper_application = {
          application: service.application || Application.new,
          constituent: service.constituent || Constituent.new
        }
        render :new, status: :unprocessable_entity
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
      constituent_params = build_constituent_params
      notification_params = build_notification_params

      # Handle both old and new parameter names for backward compatibility
      communication_preference = params[:notification_method] || params[:communication_preference]

      if communication_preference == 'email'
        ApplicationNotificationsMailer.income_threshold_exceeded(constituent_params, notification_params)
                                      .deliver_later
        flash[:notice] = 'Rejection notification has been sent.'
      elsif communication_preference == 'letter'
        flash[:notice] = 'Rejection letter has been queued for printing.'
      end

      redirect_to admin_applications_path
    end

    private

    # Logging helpers for create action
    def log_file_and_form_params
      Rails.logger.debug 'CONTROLLER - File params present:'
      Rails.logger.debug { "income_proof present: #{params[:income_proof].present?}" }
      Rails.logger.debug { "residency_proof present: #{params[:residency_proof].present?}" }
      return unless params[:income_proof].present?

      Rails.logger.debug { "income_proof class: #{params[:income_proof].class}" }
      return unless params[:income_proof].respond_to?(:original_filename)

      Rails.logger.debug { "income_proof filename: #{params[:income_proof].original_filename}" }
    end

    # Generates a success message based on rejected proofs
    def generate_success_message(application)
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

    # Builds service parameters by merging constituent, application, and proof params
    def paper_application_params
      service_params = {
        constituent: constituent_params,
        application: application_params
      }
      add_proof_params(service_params)
      Rails.logger.debug { "Final service params: #{service_params.keys.inspect}" }
      service_params
    end

    # Permitted parameters for constituent
    def constituent_params
      params.require(:constituent).permit(
        :first_name,
        :last_name,
        :email,
        :phone,
        :physical_address_1,
        :physical_address_2,
        :city,
        :state,
        :zip_code,
        :is_guardian,
        :guardian_relationship,
        :hearing_disability,
        :vision_disability,
        :speech_disability,
        :mobility_disability,
        :cognition_disability,
        :communication_preference
      )
    end

    # Permitted parameters for application
    def application_params
      params.require(:application).permit(
        :household_size,
        :annual_income,
        :maryland_resident,
        :self_certify_disability,
        :medical_provider_name,
        :medical_provider_phone,
        :medical_provider_fax,
        :medical_provider_email,
        :terms_accepted,
        :information_verified,
        :medical_release_authorized
      )
    end

    # Adds proof-related parameters into the service params
    def add_proof_params(service_params)
      %w[income residency].each do |type|
        action_key = "#{type}_proof_action"
        service_params[action_key] = params[action_key]
        file_key = "#{type}_proof"
        service_params[file_key] = params[file_key] if params[file_key].present?
        service_params["#{type}_proof_rejection_reason"] = params["#{type}_proof_rejection_reason"]
        service_params["#{type}_proof_rejection_notes"] = params["#{type}_proof_rejection_notes"]
      end
    end

    # Builds constituent parameters for rejection notifications
    def build_constituent_params
      {
        first_name: params[:first_name],
        last_name: params[:last_name],
        email: params[:email],
        phone: params[:phone]
      }
    end

    # Builds notification parameters for rejection notifications
    def build_notification_params
      {
        household_size: params[:household_size],
        annual_income: params[:annual_income],
        communication_preference: params[:communication_preference],
        additional_notes: params[:additional_notes]
      }
    end

    # Casts boolean parameters for both constituent and application
    def cast_boolean_params
      return unless params[:constituent] && params[:application]

      cast_boolean_for(params[:constituent],
                       %i[hearing_disability vision_disability speech_disability mobility_disability
                          cognition_disability is_guardian])
      cast_boolean_for(params[:application],
                       %i[self_certify_disability maryland_resident terms_accepted information_verified
                          medical_release_authorized])
    end

    # Helper to cast boolean fields in a hash
    def cast_boolean_for(hash, fields)
      fields.each do |field|
        next unless hash[field]

        value = hash[field]
        value = value.last if value.is_a?(Array)
        hash[field] = ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
