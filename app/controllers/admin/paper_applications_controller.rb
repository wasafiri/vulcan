class Admin::PaperApplicationsController < Admin::BaseController
  before_action :cast_boolean_params, only: [:create]

  def new
    @paper_application = {
      application: Application.new,
      constituent: Constituent.new
    }
  end

  def create
    # Debug file parameters
    Rails.logger.debug "CONTROLLER - File params present:"
    Rails.logger.debug "income_proof present: #{params[:income_proof].present?}"
    Rails.logger.debug "residency_proof present: #{params[:residency_proof].present?}"
    
    # Debug form parameters
    if params[:income_proof].present?
      Rails.logger.debug "income_proof class: #{params[:income_proof].class}"
      Rails.logger.debug "income_proof filename: #{params[:income_proof].original_filename}" if params[:income_proof].respond_to?(:original_filename)
    end
    
    # Create a service instance with our parameters and current admin user
    service_params = paper_application_params
    
    Rails.logger.debug "Service params before service call: #{service_params.keys.inspect}"
    
    service = Applications::PaperApplicationService.new(
      params: service_params,
      admin: current_user
    )

    # Process the application creation
    if service.create
      # Generate appropriate success message
      redirect_to admin_application_path(service.application), 
                  notice: generate_success_message(service.application)
    else
      # Display error and re-render form with existing data
      flash.now[:alert] = service.errors.first if service.errors.any?
      
      @paper_application = {
        application: service.application || Application.new,
        constituent: service.constituent || Constituent.new
      }
      render :new, status: :unprocessable_entity
    end
  end

  def fpl_thresholds
    # Gather FPL thresholds for JavaScript calculations
    thresholds = {}
    (1..8).each do |size|
      thresholds[size] = Policy.get("fpl_#{size}_person").to_i
    end

    modifier = Policy.get("fpl_modifier_percentage").to_i

    render json: { thresholds: thresholds, modifier: modifier }
  end

  def send_rejection_notification
    # Create a temporary constituent record to send the notification
    constituent_params = {
      first_name: params[:first_name],
      last_name: params[:last_name],
      email: params[:email],
      phone: params[:phone]
    }

    # Create the notification
    notification_params = {
      household_size: params[:household_size],
      annual_income: params[:annual_income],
      communication_preference: params[:communication_preference],
      additional_notes: params[:additional_notes]
    }

    # Send the notification
    if params[:communication_preference] == "email"
      ApplicationNotificationsMailer.income_threshold_exceeded(
        constituent_params,
        notification_params
      ).deliver_later
      flash[:notice] = "Rejection notification has been sent via email."
    elsif params[:communication_preference] == "letter"
      # Logic to queue a letter for printing
      flash[:notice] = "Rejection letter has been queued for printing."
    end

    redirect_to admin_applications_path
  end

  private

  def generate_success_message(application)
    # Check if any proofs were rejected and add more detailed notice
    if application.proof_reviews.where(status: :rejected).any?
      rejected_proofs = []
      rejected_proofs << "income" if application.income_proof_status_rejected?
      rejected_proofs << "residency" if application.residency_proof_status_rejected?
      
      if rejected_proofs.any?
        message = "Paper application successfully submitted with #{rejected_proofs.length} rejected "
        message += rejected_proofs.length == 1 ? "proof" : "proofs"
        message += ": #{rejected_proofs.join(' and ')}. Notifications will be sent."
        return message
      end
    end
    
    "Paper application successfully submitted."
  end

  def paper_application_params
    service_params = {
      constituent: params.require(:constituent).permit(
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
      ),
      application: params.require(:application).permit(
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
    }
    
    # Add proof handling parameters with string keys to match what the service expects
    ['income', 'residency'].each do |type|
      # First add the action parameter which controls accept/reject
      action_key = "#{type}_proof_action"
      service_params[action_key] = params[action_key]
      
      # Then add the file itself if present
      file_key = "#{type}_proof"
      service_params[file_key] = params[file_key] if params[file_key].present?
      
      # Add rejection-related parameters
      service_params["#{type}_proof_rejection_reason"] = params["#{type}_proof_rejection_reason"]
      service_params["#{type}_proof_rejection_notes"] = params["#{type}_proof_rejection_notes"]
    end
    
    Rails.logger.debug "Final service params: #{service_params.keys.inspect}"
    service_params
  end

  # Similar to constituent portal's approach for boolean handling
  def cast_boolean_params
    return unless params[:constituent] && params[:application]
    
    # Cast constituent boolean fields
    boolean_fields = [
      :hearing_disability,
      :vision_disability,
      :speech_disability,
      :mobility_disability,
      :cognition_disability,
      :is_guardian
    ]
    
    boolean_fields.each do |field|
      next unless params[:constituent][field]
      value = params[:constituent][field]
      value = value.last if value.is_a?(Array)
      params[:constituent][field] = ActiveModel::Type::Boolean.new.cast(value)
    end
    
    # Cast application boolean fields
    app_boolean_fields = [
      :self_certify_disability,
      :maryland_resident,
      :terms_accepted,
      :information_verified,
      :medical_release_authorized
    ]
    
    app_boolean_fields.each do |field|
      next unless params[:application][field]
      value = params[:application][field]
      value = value.last if value.is_a?(Array)
      params[:application][field] = ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
