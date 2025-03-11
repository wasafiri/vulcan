module ProofConsistencyValidation
  extend ActiveSupport::Concern

  included do
    validate :proofs_consistent_with_status
  end

  private

  def proofs_consistent_with_status
    # Check income proof
    if income_proof_status.in?(['approved', 'rejected']) && !income_proof.attached?
      errors.add(:income_proof, "must be attached if status is #{income_proof_status}")
    end

    # Check residency proof
    if residency_proof_status.in?(['approved', 'rejected']) && !residency_proof.attached?
      errors.add(:residency_proof, "must be attached if status is #{residency_proof_status}")
    end
  end
end
