class Applications::ProofReviewer
  def initialize(application, admin)
    @application = application
    @admin = admin
  end

  def review(proof_type:, status:, rejection_reason: nil)
    ApplicationRecord.transaction do
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
    @proof_review = @application.proof_reviews.create!(
      admin: @admin,
      proof_type: type.to_sym, # Ensure we pass a symbol for the enum
      status: status,
      rejection_reason: reason
    )
  end

  def update_proof_status(proof_type, status)
    case proof_type.to_s
    when "income"
      @application.update!(income_proof_status: status)
    when "residency"
      @application.update!(residency_proof_status: status)
    end
  end

  def check_all_proofs_approved
    if @application.all_proofs_approved?
      MedicalProviderMailer.request_certification(@application).deliver_now
      @application.update!(status: :awaiting_documents)
    end
  end
end
