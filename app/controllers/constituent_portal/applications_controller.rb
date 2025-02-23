module ConstituentPortal
  class ApplicationsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_constituent!
    before_action :set_application, except: [ :index, :new, :create ]

    def index
      @applications = current_user.applications.order(created_at: :desc)
    end

    def show
    end

    def new
      @application = current_user.applications.new
    end

    def create
      @application = current_user.applications.new(application_params)

      if @application.save
        redirect_to constituent_portal_application_path(@application),
          notice: "Application created successfully"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @application.update(application_params)
        redirect_to constituent_portal_application_path(@application),
          notice: "Application updated successfully"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def upload_documents
      if @application.update(document_params)
        redirect_to constituent_portal_application_path(@application),
          notice: "Documents uploaded successfully"
      else
        redirect_to constituent_portal_application_path(@application),
          alert: "Failed to upload documents"
      end
    end

    def request_review
      @application.request_review!
      redirect_to constituent_portal_application_path(@application),
        notice: "Review requested successfully"
    end

    def verify
      @application.verify!
      redirect_to constituent_portal_application_path(@application),
        notice: "Application verified successfully"
    end

    def submit
      if @application.submit!
        redirect_to constituent_portal_application_path(@application),
          notice: "Application submitted successfully"
      else
        redirect_to constituent_portal_application_path(@application),
          alert: "Failed to submit application"
      end
    end

    def resubmit_proof
      if @application.resubmit_proof!
        redirect_to constituent_portal_application_path(@application),
          notice: "Proof resubmitted successfully"
      else
        redirect_to constituent_portal_application_path(@application),
          alert: "Failed to resubmit proof"
      end
    end

    private

    def set_application
      @application = current_user.applications.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to constituent_portal_dashboard_path, alert: "Application not found"
    end

    def require_constituent!
      unless current_user&.constituent?
        redirect_to root_path, alert: "Access denied"
      end
    end

    def application_params
      params.require(:application).permit(
        :application_type,
        :submission_method,
        :household_size,
        :annual_income,
        :income_details,
        :residency_details,
        :medical_provider_name,
        :medical_provider_phone,
        :medical_provider_fax,
        :medical_provider_email
      )
    end

    def document_params
      params.require(:application).permit(:income_proof, :residency_proof)
    end
  end
end
