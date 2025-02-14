class Applications::ProofReviewer
  def initialize(application, admin)
    @application = application
    @admin = admin
  end

  def review(proof_type:, status:, rejection_reason: nil)
    ApplicationRecord.transaction do
      # Convert status to symbol if it's a string
      status = status.to_sym if status.is_a?(String)

      @proof_review = create_proof_review(proof_type, status, rejection_reason)
      update_proof_status(proof_type, status)
      check_all_proofs_approved if status == :approved
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Proof review failed: #{e.message}"
    false
  end

  private

  def create_proof_review(type, status, reason)
    # Ensure we're using strings consistently for proof_type to match the enum keys
    proof_type_key = type.to_s

    @proof_review = @application.proof_reviews.create!(
      admin: @admin,
      proof_type: proof_type_key,
      status: status,
      rejection_reason: reason
    )
  end

  def update_proof_status(proof_type, status)
    status_key = status.to_sym
    case proof_type.to_s
    when "income"
      @application.update!(income_proof_status: status_key)
    when "residency"
      @application.update!(residency_proof_status: status_key)
    end
  end

  def check_all_proofs_approved
    if @application.all_proofs_approved?
      MedicalProviderMailer.request_certification(@application).deliver_now
      @application.update!(status: :awaiting_documents)
    end
  end
end
