class Admin::PaperApplicationsController < Admin::BaseController
  before_action :set_paper_application_context, only: [:create]
  skip_before_action :verify_authenticity_token, only: [:direct_upload]

  def new
    @paper_application = {
      application: Application.new,
      constituent: Constituent.new
    }
  end

  # Direct upload endpoint for client-side uploads to S3
  def direct_upload
    blob = ActiveStorage::Blob.create_before_direct_upload!(blob_params)
    render json: direct_upload_json(blob)
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    # Log file upload information for debugging
    if params[:income_proof].present?
      Rails.logger.info "INCOME PROOF FILE: Class=#{params[:income_proof].class.name}, Size=#{params[:income_proof].size}"
    else
      Rails.logger.info "No income proof file uploaded"
    end
    
    if params[:residency_proof].present?
      Rails.logger.info "RESIDENCY PROOF FILE: Class=#{params[:residency_proof].class.name}, Size=#{params[:residency_proof].size}"
    else
      Rails.logger.info "No residency proof file uploaded"
    end

    service = Applications::PaperApplicationService.new(
      params: paper_application_params,
      admin: current_user
    )

    if service.create
      # Force reload the application to ensure attachments are visible
      service.application.reload
      
      # Check if any proofs were rejected and add more detailed notice
      if service.application.proof_reviews.where(status: :rejected).any?
        rejected_proofs = []
        rejected_proofs << "income" if service.application.income_proof_status_rejected?
        rejected_proofs << "residency" if service.application.residency_proof_status_rejected?
        
        if rejected_proofs.any?
          notice_message = "Paper application successfully submitted with #{rejected_proofs.length} rejected "
          notice_message += rejected_proofs.length == 1 ? "proof" : "proofs"
          notice_message += ": #{rejected_proofs.join(' and ')}. Notifications will be sent."
        else
          notice_message = "Paper application successfully submitted."
        end
      else
        notice_message = "Paper application successfully submitted."
      end
      
      # Double-check attachments
      if params[:income_proof].present? && !service.application.income_proof.attached?
        notice_message += " Warning: Income proof attachment may need review."
      end
      
      if params[:residency_proof].present? && !service.application.residency_proof.attached?
        notice_message += " Warning: Residency proof attachment may need review."
      end
      
      redirect_to admin_application_path(service.application), notice: notice_message
    else
      if params[:income_proof].present? || params[:residency_proof].present?
        # Add message about preserving attachments
        flash.now[:alert] = "#{service.errors.first} Your uploaded files have been preserved." if service.errors.any?
      else
        # Regular error message
        flash.now[:alert] = service.errors.first if service.errors.any?
      end
      
      @paper_application = {
        application: service.application || Application.new,
        constituent: service.constituent || Constituent.new
      }
      render :new, status: :unprocessable_entity
    end
  end

  def fpl_thresholds
    # Get FPL thresholds from the Policy model
    thresholds = {}
    (1..8).each do |size|
      thresholds[size] = Policy.get("fpl_#{size}_person").to_i
    end

    # Get the modifier percentage
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
      notification_method: params[:notification_method],
      additional_notes: params[:additional_notes]
    }

    # Send the notification
    ApplicationNotificationsMailer.income_threshold_exceeded(
      constituent_params,
      notification_params
    ).deliver_later if params[:notification_method] == "email"

    # If it's a letter, queue it for printing
    if params[:notification_method] == "letter"
      # Logic to queue a letter for printing
      # This could be a background job or another service
      flash[:notice] = "Rejection letter has been queued for printing."
    else
      flash[:notice] = "Rejection notification has been sent via email."
    end

    redirect_to admin_applications_path
  end

  private

  def set_paper_application_context
    # Set thread variable to indicate we're in a paper application context
    # This will be used by the model validations to skip certain checks
    Thread.current[:paper_application_context] = true
  end

  # Direct upload helper methods
  def blob_params
    params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type, metadata: {})
  end

  def direct_upload_json(blob)
    {
      signed_id: blob.signed_id,
      direct_upload: {
        url: blob.service_url_for_direct_upload,
        headers: blob.service_headers_for_direct_upload
      }
    }
  end

  def paper_application_params
    {
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
        :cognition_disability
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
      ),
      income_proof_action: params[:income_proof_action],
      income_proof: params[:income_proof],
      income_proof_signed_id: params[:income_proof_signed_id],
      income_proof_rejection_reason: params[:income_proof_rejection_reason],
      income_proof_rejection_notes: params[:income_proof_rejection_notes],
      residency_proof_action: params[:residency_proof_action],
      residency_proof: params[:residency_proof],
      residency_proof_signed_id: params[:residency_proof_signed_id],
      residency_proof_rejection_reason: params[:residency_proof_rejection_reason],
      residency_proof_rejection_notes: params[:residency_proof_rejection_notes]
    }
  end
end
