class Constituent::ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!
  before_action :set_application, only: [ :show, :edit, :update, :verify, :submit ]
  before_action :ensure_editable, only: [ :edit, :update ]

  def new
    @application = current_user.applications.new
  end

  def index
    @applications = current_user.applications
  end

  def create
    @application = current_user.applications.new(application_params.except(
      :is_guardian, :guardian_relationship, :hearing_disability,
      :vision_disability, :speech_disability, :mobility_disability,
      :cognition_disability
    ))

    # Determine the status based on the button clicked
    if params[:submit_application]
      @application.status = :in_progress
    else
      @application.status = :draft
    end

    @application.application_date = Time.current
    @application.submission_method = :online

    # Add medical provider info from nested params
    if params[:application][:medical_provider].present?
      medical_provider_attrs = params[:application][:medical_provider].permit(
        :name, :phone, :fax, :email
      )
      @application.medical_provider_name = medical_provider_attrs[:name]
      @application.medical_provider_phone = medical_provider_attrs[:phone]
      @application.medical_provider_fax = medical_provider_attrs[:fax]
      @application.medical_provider_email = medical_provider_attrs[:email]
    end

    # Extract user attributes
    user_attrs = {
      is_guardian: params[:application][:is_guardian] == "1",
      guardian_relationship: params[:application][:guardian_relationship],
      hearing_disability: params[:application][:hearing_disability] == "1",
      vision_disability: params[:application][:vision_disability] == "1",
      speech_disability: params[:application][:speech_disability] == "1",
      mobility_disability: params[:application][:mobility_disability] == "1",
      cognition_disability: params[:application][:cognition_disability] == "1"
    }

    Rails.logger.debug "Application attributes: #{@application.attributes.inspect}"
    Rails.logger.debug "Application valid? #{@application.valid?}"
    Rails.logger.debug "Application errors: #{@application.errors.full_messages}" if @application.invalid?

    ActiveRecord::Base.transaction do
      if @application.valid? && update_user_attributes(user_attrs) && @application.save
        if params[:submit_application]
          @application.update(status: :in_progress)
          redirect_to constituent_application_path(@application),
                      notice: "Application submitted successfully!"
        else
          redirect_to constituent_application_path(@application),
                      notice: "Application saved as draft."
        end
      else
        @application.errors.merge!(current_user.errors)
        render :new, status: :unprocessable_entity
      end
    end
  end

  def show
  end

  def edit
  end

  def update
    ActiveRecord::Base.transaction do
      # Handle medical provider attributes first
      if params[:medical_provider].present?
        medical_provider_attrs = params[:medical_provider].permit(
          :name, :phone, :fax, :email
        )
        @application.medical_provider_name = medical_provider_attrs[:name]
        @application.medical_provider_phone = medical_provider_attrs[:phone]
        @application.medical_provider_fax = medical_provider_attrs[:fax]
        @application.medical_provider_email = medical_provider_attrs[:email]
      end

      # Clean annual income and prepare application attributes
      application_attrs = application_params.merge(
        annual_income: params[:application][:annual_income]&.gsub(/[^\d.]/, "")
      )

      # Extract user-related attributes
      user_attrs = {
        is_guardian: params[:application][:is_guardian] == "1",
        guardian_relationship: params[:application][:guardian_relationship],
        hearing_disability: params[:application][:hearing_disability] == "1",
        vision_disability: params[:application][:vision_disability] == "1",
        speech_disability: params[:application][:speech_disability] == "1",
        mobility_disability: params[:application][:mobility_disability] == "1",
        cognition_disability: params[:application][:cognition_disability] == "1"
      }

      # Remove user-related attributes from application_params
      clean_application_attrs = application_attrs.except(
        :is_guardian,
        :guardian_relationship,
        :hearing_disability,
        :vision_disability,
        :speech_disability,
        :mobility_disability,
        :cognition_disability
      )

      Rails.logger.debug "Clean application attrs before save: #{clean_application_attrs.inspect}"

      if params[:save_draft]
        if @application.update(clean_application_attrs)
          update_user_attributes(user_attrs)
          redirect_to constituent_application_path(@application),
                      notice: "Application saved as draft."
        else
          Rails.logger.debug "Application errors: #{@application.errors.full_messages}"
          render :edit, status: :unprocessable_entity
        end
      elsif params[:submit_application]
        if @application.update(clean_application_attrs)
          update_user_attributes(user_attrs)
          @application.update(status: :in_progress)
          redirect_to constituent_application_path(@application),
                      notice: "Application submitted successfully!"
        else
          Rails.logger.debug "Application errors: #{@application.errors.full_messages}"
          render :edit, status: :unprocessable_entity
        end
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Update failed: #{e.record.errors.full_messages.join(', ')}"
    render :edit, status: :unprocessable_entity
  end

  private

  def update_user_attributes(attrs)
    Rails.logger.debug "Updating user attributes: #{attrs.inspect}"
    Rails.logger.debug "Current user class: #{current_user.class}"
    Rails.logger.debug "Current user attributes: #{current_user.attributes.keys}"

    # Try update first
    result = current_user.update(
      is_guardian: attrs[:is_guardian],
      guardian_relationship: attrs[:guardian_relationship],
      hearing_disability: attrs[:hearing_disability],
      vision_disability: attrs[:vision_disability],
      speech_disability: attrs[:speech_disability],
      mobility_disability: attrs[:mobility_disability],
      cognition_disability: attrs[:cognition_disability]
    )

    # If update fails, add detailed error logging
    unless result
      Rails.logger.error "Update failed."
      Rails.logger.error "Current user errors: #{current_user.errors.full_messages}"

      # Fall back to update_columns
      result = current_user.update_columns(
        is_guardian: ActiveModel::Type::Boolean.new.cast(attrs[:is_guardian]),
        guardian_relationship: attrs[:guardian_relationship],
        hearing_disability: ActiveModel::Type::Boolean.new.cast(attrs[:hearing_disability]),
        vision_disability: ActiveModel::Type::Boolean.new.cast(attrs[:vision_disability]),
        speech_disability: ActiveModel::Type::Boolean.new.cast(attrs[:speech_disability]),
        mobility_disability: ActiveModel::Type::Boolean.new.cast(attrs[:mobility_disability]),
        cognition_disability: ActiveModel::Type::Boolean.new.cast(attrs[:cognition_disability])
      )
    end

    unless result
      Rails.logger.error "Failed to update user attributes: #{current_user.errors.full_messages}"
    end

    result
  end

  def verify
    redirect_to constituent_application_path(@application) unless @application.draft?
  end

  def upload_documents
    @application = current_user.applications.find(params[:id])

    if params[:documents].present?
      params[:documents].each do |document_type, file|
        case document_type
        when "income_proof"
          @application.income_proof.attach(file)
        when "residency_proof"
          @application.residency_proof.attach(file)
        end
      end

      if @application.save
        redirect_to constituent_application_path(@application),
          notice: "Documents uploaded successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      redirect_to constituent_application_path(@application),
        alert: "Please select documents to upload."
    end
  end

  def request_review
    @application = current_user.applications.find(params[:id])

    if @application.update(needs_review_since: Time.current)
      # Notify admins about the review request
      User.where(type: "Admin").find_each do |admin|
        Notification.create!(
          recipient: admin,
          actor: current_user,
          action: "review_requested",
          notifiable: @application
        )
      end

      redirect_to constituent_application_path(@application),
        notice: "Review requested successfully."
    else
      redirect_to constituent_application_path(@application),
        alert: "Unable to request review at this time."
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
      redirect_to constituent_application_path(@application),
        notice: "Application submitted successfully!"
    else
      render :verify, status: :unprocessable_entity
    end
  end

  private

  def submission_params
    params.require(:application).permit(
      :terms_accepted,
      :information_verified,
      :medical_release_authorized
    )
  end

  def set_application
    @application = current_user.applications.find(params[:id])
  end

  def ensure_editable
    unless @application.draft?
      redirect_to constituent_application_path(@application),
                  alert: "This application has already been submitted and cannot be edited."
    end
  end

  def application_params
    params.require(:application).permit(
      :maryland_resident,
      :annual_income,
      :household_size,
      :self_certify_disability,
      :residency_proof,
      :income_proof,
      :medical_provider_name,
      :medical_provider_phone,
      :medical_provider_fax,
      :medical_provider_email,

      # Added verification fields
      :terms_accepted,
      :information_verified,
      :medical_release_authorized,

      # These will be moved to user_params
      :is_guardian,
      :guardian_relationship,
      :hearing_disability,
      :vision_disability,
      :speech_disability,
      :mobility_disability,
      :cognition_disability
    )
  end

  def user_params
    params.require(:application).permit(
      :is_guardian,
      :guardian_relationship,
      :hearing_disability,
      :vision_disability,
      :speech_disability,
      :mobility_disability,
      :cognition_disability
    ).transform_values { |v| ActiveModel::Type::Boolean.new.cast(v) }
  end

  def verification_params
    params.require(:application).permit(
      :terms_accepted,
      :information_verified,
      :medical_release_authorized
    )
  end

  def medical_provider_params
    return {} unless params[:medical_provider]

    params.require(:medical_provider).permit(
      :name,
      :phone,
      :fax,
      :email
    ).transform_keys { |key| "medical_provider_#{key}" }
  end

  def require_constituent!
    unless current_user&.constituent?
      redirect_to root_path, alert: "Access denied. Constituent-only area."
    end
  end
end
