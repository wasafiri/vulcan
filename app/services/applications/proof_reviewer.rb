class Applications::ProofReviewer
  def initialize(application, admin)
    @application = application
    @admin = admin
  end

  def review(proof_type:, status:, rejection_reason: nil)
    ApplicationRecord.transaction do
      create_proof_review(proof_type, status, rejection_reason)
      update_application_status(proof_type, status)
      notify_constituent if status == :rejected
      check_all_proofs_approved
    end
  end

  private

  def create_proof_review(type, status, reason)
    @application.proof_reviews.create!(
      admin: @admin,
      proof_type: type,
      status: status,
      rejection_reason: reason
    )
  end

  # ... remaining private methods
end
