class Admin::ScannedProofsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_application
  before_action :validate_proof_type, only: [ :new, :create ]
  before_action :validate_file, only: [ :create ]

  ALLOWED_CONTENT_TYPES = [
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/tiff"
  ].freeze

  MAX_FILE_SIZE = 10.megabytes

  def new
    @proof_type = params[:proof_type]
  end

  def create
    ActiveRecord::Base.transaction do
      attach_proof
      create_audit_trail
    end

    # Keep notifications outside transaction
    notify_constituent

    redirect_to admin_application_path(@application),
      notice: "Proof successfully uploaded and attached"

  rescue ActiveRecord::RecordInvalid, ActiveStorage::IntegrityError => e
    redirect_to new_admin_application_scanned_proof_path(@application),
      alert: e.message
  rescue StandardError => e
    Rails.logger.error("Proof upload failed: #{e.message}")
    redirect_to new_admin_application_scanned_proof_path(@application),
      alert: "Error uploading proof. Please try again."
  end

  private

  def set_application
    @application = Application.find(params[:application_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_applications_path, alert: "Application not found"
  end

  def validate_proof_type
    unless %w[income residency].include?(params[:proof_type])
      redirect_to admin_application_path(@application),
        alert: "Invalid proof type"
    end
  end

  def validate_file
    redirect_to(new_admin_application_scanned_proof_path(@application),
      alert: "Please select a file to upload") unless params[:file].present?

    redirect_to(new_admin_application_scanned_proof_path(@application),
      alert: "File type not allowed") unless valid_file_type?

    redirect_to(new_admin_application_scanned_proof_path(@application),
      alert: "File size must be under #{MAX_FILE_SIZE/1.megabyte}MB") unless valid_file_size?
  end

  def valid_file_type?
    ALLOWED_CONTENT_TYPES.include?(params[:file].content_type)
  end

  def valid_file_size?
    params[:file].size <= MAX_FILE_SIZE
  end

  def attach_proof
    case params[:proof_type]
    when 'income'
      @application.income_proof.attach(params[:file])
      proof_type = :income_proof_status
    when 'residency'
      @application.residency_proof.attach(params[:file])
      proof_type = :residency_proof_status
    else
      raise ArgumentError, "Invalid proof type"
    end
  
    @application.update!(
      proof_type => :not_reviewed,
      needs_review_since: Time.current,
      last_proof_submitted_at: Time.current
    )
  end

  def create_audit_trail
    ProofSubmissionAudit.create!(
      application: @application,
      user: current_user,
      proof_type: params[:proof_type],
      submission_method: "scanned",
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      filename: params[:file].original_filename,
      file_size: params[:file].size,
      content_type: params[:file].content_type
    )
  end

  def notify_constituent
    ApplicationNotificationsMailer.proof_received(
      @application,
      params[:proof_type]
    ).deliver_later
  rescue StandardError => e
    Rails.logger.error("Failed to queue notification: #{e.message}")
    # Continue without failing the upload
  end
end
