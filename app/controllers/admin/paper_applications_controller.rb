class Admin::PaperApplicationsController < Admin::BaseController
  def new
    @paper_application = {
      application: Application.new,
      constituent: Constituent.new
    }
  end

  def create
    ActiveRecord::Base.transaction do
      # Check if constituent already has an active application
      if existing_constituent = find_existing_constituent(constituent_params)
        if existing_constituent.active_application?
          flash[:alert] = "This constituent already has an active application."
          return render :new, status: :unprocessable_entity
        end
        @constituent = existing_constituent
      else
        # Create new constituent with a temporary password
        @constituent = create_new_constituent(constituent_params)
      end

      # Create application
      @application = @constituent.applications.new(application_params)
      @application.submission_method = :paper
      @application.application_date = Time.current
      @application.status = :in_progress

      # Validate income threshold
      unless income_within_threshold?(@application.household_size, @application.annual_income)
        flash[:alert] = "Income exceeds the maximum threshold for the household size."
        return render :new, status: :unprocessable_entity
      end

      # Handle proof uploads and rejections
      handle_proof_uploads(@application)

      if @application.save
        # Send notifications for rejected proofs if any
        send_proof_rejection_notifications(@application)

        redirect_to admin_application_path(@application), notice: "Paper application successfully submitted."
      else
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Error: #{e.message}"
    render :new, status: :unprocessable_entity
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

  def find_existing_constituent(params)
    # Try to find existing constituent by email or phone
    constituent = Constituent.find_by(email: params[:email]) if params[:email].present?
    constituent ||= Constituent.find_by(phone: params[:phone]) if params[:phone].present?
    constituent
  end

  def create_new_constituent(params)
    # Generate a secure random password
    temp_password = SecureRandom.hex(8)

    # Create the constituent with the temporary password
    constituent = Constituent.new(params)
    constituent.password = temp_password
    constituent.password_confirmation = temp_password
    constituent.verified = true # Mark as verified since admin is creating it
    constituent.save!

    # Send account creation notification with the temporary password
    ApplicationNotificationsMailer.account_created(constituent, temp_password).deliver_later

    constituent
  end

  def income_within_threshold?(household_size, annual_income)
    # Get the base FPL amount for the household size
    base_fpl = Policy.get("fpl_#{[ household_size, 8 ].min}_person").to_i

    # Get the modifier percentage
    modifier = Policy.get("fpl_modifier_percentage").to_i

    # Calculate the threshold
    threshold = base_fpl * (modifier / 100.0)

    # Check if income is within threshold
    annual_income <= threshold
  end

  def handle_proof_uploads(application)
    # Handle income proof
    case params[:income_proof_action]
    when "accept"
      if params[:income_proof].present?
        application.income_proof.attach(params[:income_proof])
        application.income_proof_status = :approved
      end
    when "reject"
      # Always attach the proof if provided, even if rejecting it
      if params[:income_proof].present?
        application.income_proof.attach(params[:income_proof])
      end

      application.income_proof_status = :rejected

      # Only create a proof review record if the proof is attached
      # This prevents the validation error when rejecting a proof that wasn't provided
      if params[:income_proof].present? || !Rails.env.production?
        @income_proof_review = application.proof_reviews.build(
          admin: current_user || User.system_user,
          proof_type: :income,
          status: :rejected,
          rejection_reason: params[:income_proof_rejection_reason],
          notes: params[:income_proof_rejection_notes],
          submission_method: :paper,
          reviewed_at: Time.current
        )

        unless @income_proof_review.save
          Rails.logger.error "Failed to create income proof review: #{@income_proof_review.errors.full_messages.join(', ')}"
          raise ActiveRecord::RecordInvalid.new(@income_proof_review)
        end
      else
        Rails.logger.info "Skipping income proof review creation because no proof was attached"
      end
    end

    # Handle residency proof (similar logic)
    case params[:residency_proof_action]
    when "accept"
      if params[:residency_proof].present?
        application.residency_proof.attach(params[:residency_proof])
        application.residency_proof_status = :approved
      end
    when "reject"
      # Always attach the proof if provided, even if rejecting it
      if params[:residency_proof].present?
        application.residency_proof.attach(params[:residency_proof])
      end

      application.residency_proof_status = :rejected

      # Only create a proof review record if the proof is attached
      # This prevents the validation error when rejecting a proof that wasn't provided
      if params[:residency_proof].present? || !Rails.env.production?
        @residency_proof_review = application.proof_reviews.build(
          admin: current_user || User.system_user,
          proof_type: :residency,
          status: :rejected,
          rejection_reason: params[:residency_proof_rejection_reason],
          notes: params[:residency_proof_rejection_notes],
          submission_method: :paper,
          reviewed_at: Time.current
        )

        unless @residency_proof_review.save
          Rails.logger.error "Failed to create residency proof review: #{@residency_proof_review.errors.full_messages.join(', ')}"
          raise ActiveRecord::RecordInvalid.new(@residency_proof_review)
        end
      else
        Rails.logger.info "Skipping residency proof review creation because no proof was attached"
      end
    end
  end

  def send_proof_rejection_notifications(application)
    # Send email notifications for rejected proofs
    if application.income_proof_status_rejected? && @income_proof_review.present?
      ApplicationNotificationsMailer.proof_rejected(
        application,
        @income_proof_review
      ).deliver_later
    end

    if application.residency_proof_status_rejected? && @residency_proof_review.present?
      ApplicationNotificationsMailer.proof_rejected(
        application,
        @residency_proof_review
      ).deliver_later
    end
  end

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
      :cognition_disability
    )
  end

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
end
