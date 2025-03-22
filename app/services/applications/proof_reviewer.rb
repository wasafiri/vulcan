class Applications::ProofReviewer
  def initialize(application, admin)
    @application = application
    @admin = admin
  end

  def review(proof_type:, status:, rejection_reason: nil, notes: nil)
    Rails.logger.info "Starting review with proof_type: #{proof_type.inspect}, status: #{status.inspect}"

    # Store the string values we'll need for application status
    @proof_type_key = proof_type.to_s
    @status_key = status.to_s

    Rails.logger.info "Converted values - proof_type: #{@proof_type_key.inspect}, status: #{@status_key.inspect}"

    # Create the proof review and update application status in a transaction
    ApplicationRecord.transaction do
      Rails.logger.info 'Creating proof review record'
      @proof_review = @application.proof_reviews.create!(
        admin: @admin,
        proof_type: @proof_type_key,
        status: @status_key,
        rejection_reason: rejection_reason,
        notes: notes
      )
      Rails.logger.info "Created ProofReview ID: #{@proof_review.id}, status: #{@proof_review.status}, proof_type: #{@proof_review.proof_type}"

      # Update application status directly
      update_application_status
      Rails.logger.info 'Updated application status'
    end

    # Return true to indicate success
    # Notifications are handled by ProofReview model callbacks
    true
  rescue StandardError => e
    Rails.logger.error "Proof review failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise # Re-raise to ensure errors are visible
  end

  private

  def update_application_status
    Rails.logger.info "Updating application status for proof_type: #{@proof_type_key}, status: #{@status_key}"

    # First validate if the specific proof being updated is attached if we're approving it
    if @status_key == 'approved'
      attachment = @application.send(@proof_type_key + "_proof")
      unless attachment.attached?
        raise ActiveRecord::RecordInvalid.new(@application), "#{@proof_type_key.capitalize} proof must be attached to approve"
      end
    end

    # Use update_column to bypass validations for this specific field only
    column_name = "#{@proof_type_key}_proof_status"
    status_enum_value = Application.send("#{column_name.pluralize}").fetch(@status_key.to_sym)
    @application.update_column(column_name, status_enum_value)
    
    # Reload the application to ensure it has the latest data
    @application.reload

    # Check if auto-approval is now possible
    check_for_auto_approval
  end

  def check_for_auto_approval
    # Only check for auto-approval if we're not already approved
    return if @application.status_approved?
    
    # Check if all requirements are met
    if @application.income_proof_status_approved? && 
       @application.residency_proof_status_approved? && 
       @application.medical_certification_status_accepted?
       
      # Auto-approve using update_column to avoid triggering other validations
      @application.update_column(:status, Application.statuses[:approved])
      
      # Create an event for this automated approval
      Event.create!(
        user: @admin,
        action: 'application_auto_approved',
        metadata: {
          application_id: @application.id,
          timestamp: Time.current.iso8601,
          trigger: "proof_#{@proof_type_key}_approved"
        }
      )
      
      Rails.logger.info "Application #{@application.id} auto-approved after all proofs were validated"
    end
  end
end
