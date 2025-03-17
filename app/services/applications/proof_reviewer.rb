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

    case @proof_type_key
    when 'income'
      @application.update!(income_proof_status: @status_key)
    when 'residency'
      @application.update!(residency_proof_status: @status_key)
    end
  end
end
