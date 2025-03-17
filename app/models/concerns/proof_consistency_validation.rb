module ProofConsistencyValidation
  extend ActiveSupport::Concern

  included do
    validate :proofs_consistent_with_status
  end

  private

  def proofs_consistent_with_status
    # Skip validation for paper applications
    return if submission_method&.to_sym == :paper

    check_proof_consistency(:income_proof, income_proof_status, income_proof)
    check_proof_consistency(:residency_proof, residency_proof_status, residency_proof)
  end

  def check_proof_consistency(proof_sym, status, attachment)
    return unless status.in?(%w[approved rejected]) && !attachment.attached?

    errors.add(proof_sym, "must be attached if status is #{status}")
  end
end
