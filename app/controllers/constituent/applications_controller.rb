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

    @application.status = :draft
    @application.application_date = Time.current
    @application.submission_method = :online

    # Add medical provider info
    if params[:medical_provider]
      medical_provider_attrs = params[:medical_provider].permit(
        :name, :phone, :fax, :email
      ).transform_keys { |key| "medical_provider_#{key}" }
      @application.assign_attributes(medical_provider_attrs)
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
        redirect_to constituent_application_path(@application),
                    notice: "Application saved as draft."
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
      # Clean annual income and prepare application attributes
      medical_provider_attrs = params.require(:medical_provider).permit(
        :name, :phone, :fax, :email
      ).transform_keys { |key| "medical_provider_#{key}" }

      application_attrs = application_params.merge(
        annual_income: params[:application][:annual_income]&.gsub(/[^\d.]/, "")
      ).merge(medical_provider_attrs)

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
    # Directly update the database without using model setters
    current_user.update_columns(
      is_guardian: attrs[:is_guardian],
      guardian_relationship: attrs[:guardian_relationship],
      hearing_disability: attrs[:hearing_disability],
      vision_disability: attrs[:vision_disability],
      speech_disability: attrs[:speech_disability],
      mobility_disability: attrs[:mobility_disability],
      cognition_disability: attrs[:cognition_disability]
    )
  end

  def verify
    redirect_to constituent_application_path(@application) unless @application.draft?
  end

  def submit
    if @application.update(verification_params.merge(status: :in_progress))
      redirect_to constituent_application_path(@application),
                  notice: "Application submitted successfully!"
    else
      render :verify, status: :unprocessable_entity
    end
  end

  private

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
      # Current fields
      :maryland_resident,
      :annual_income,
      :household_size,
      :self_certify_disability,
      :residency_proof,
      :income_proof,

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
