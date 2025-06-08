# frozen_string_literal: true

module ProofConsistencyValidation
  extend ActiveSupport::Concern

  included do
    validate :validate_proof_status_consistent_with_application_status, unless: :skip_proof_validation?
  end

  # Validation method for proof status consistency with application status
  def validate_proof_status_consistent_with_application_status
    proofs_consistent_with_status
  end

  # Helper method to check if proof validation should be skipped
  def skip_proof_validation?
    Current.paper_context?
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
