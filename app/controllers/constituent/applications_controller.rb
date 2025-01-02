class Constituent::ApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!
  before_action :set_application, only: [ :show, :edit, :update, :verify, :submit ]
  before_action :ensure_editable, only: [ :edit, :update ]

  def new
    @application = current_user.applications.new
    @application.build_medical_provider
  end

  def index
    @applications = current_user.applications
  end

  def create
    ActiveRecord::Base.transaction do
      # Add error handling for required fields
      if params.dig(:medical_provider, :name).blank?
        @application = current_user.applications.new
        @application.errors.add(:base, "Medical provider information is required")
        return render :new, status: :unprocessable_entity
      end

      user_attrs = {
        is_guardian: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :is_guardian)),
        guardian_relationship: params.dig(:application, :guardian_relationship),
        hearing_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :hearing_disability)),
        vision_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :vision_disability)),
        speech_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :speech_disability)),
        mobility_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :mobility_disability)),
        cognition_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :cognition_disability))
      }.compact

      @application = current_user.applications.new(
        application_date: Time.current,
        status: :in_progress,
        submission_method: :online,
        draft: true,
        maryland_resident: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :maryland_resident)),
        self_certify_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :self_certify_disability)),
        medical_provider_name: params.dig(:medical_provider, :name),
        medical_provider_phone: params.dig(:medical_provider, :phone),
        medical_provider_fax: params.dig(:medical_provider, :fax),
        medical_provider_email: params.dig(:medical_provider, :email)
      )

      # **Assign Uploaded Files Using `attach`**
      @application.residency_proof.attach(params[:application][:residency_proof]) if params[:application][:residency_proof].present?
      @application.income_proof.attach(params[:application][:income_proof]) if params[:application][:income_proof].present?

      if current_user.update(user_attrs) && @application.save
        redirect_to constituent_application_path(@application), notice: "Application saved as draft."
      else
        @application.errors.merge!(current_user.errors)
        render :new, status: :unprocessable_entity
      end
    end
  end

  def show
  end

  def edit
    @application.build_medical_provider unless @application.medical_provider.present?
  end

  def update
    ActiveRecord::Base.transaction do
      # Add error handling for required fields
      if params.dig(:medical_provider, :name).blank?
        @application.errors.add(:base, "Medical provider information is required")
        return render :edit, status: :unprocessable_entity
      end

      user_attrs = {
        is_guardian: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :is_guardian)),
        guardian_relationship: params.dig(:application, :guardian_relationship),
        hearing_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :hearing_disability)),
        vision_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :vision_disability)),
        speech_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :speech_disability)),
        mobility_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :mobility_disability)),
        cognition_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :cognition_disability))
      }.compact

      application_attrs = {
        maryland_resident: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :maryland_resident)),
        self_certify_disability: ActiveModel::Type::Boolean.new.cast(params.dig(:application, :self_certify_disability)),
        medical_provider_name: params.dig(:medical_provider, :name),
        medical_provider_phone: params.dig(:medical_provider, :phone),
        medical_provider_fax: params.dig(:medical_provider, :fax),
        medical_provider_email: params.dig(:medical_provider, :email)
      }

      # **Assign Uploaded Files Using `attach`**
      @application.residency_proof.attach(params[:application][:residency_proof]) if params[:application][:residency_proof].present?
      @application.income_proof.attach(params[:application][:income_proof]) if params[:application][:income_proof].present?

      if params[:submit_for_verification]
        if current_user.update(user_attrs) && @application.update(application_attrs)
          redirect_to verify_constituent_application_path(@application)
        else
          @application.errors.merge!(current_user.errors)
          render :edit, status: :unprocessable_entity
        end
      else
        # Regular draft save
        if @application.update(application_attrs)
          redirect_to constituent_application_path(@application), notice: "Application saved as draft."
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end

  def verify
    redirect_to constituent_application_path(@application) unless @application.draft?
  end

  def submit
    if @application.update(verification_params.merge(draft: false))
      redirect_to constituent_application_path(@application), notice: "Application submitted successfully!"
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

  def verification_params
    params.require(:application).permit(
      :terms_accepted,
      :information_verified,
      :medical_release_authorized
    )
  end

  def require_constituent!
    unless current_user&.constituent?
      redirect_to root_path, alert: "Access denied. Constituent-only area."
    end
  end
end
