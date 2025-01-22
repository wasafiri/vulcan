# app/models/concerns/proof_manageable.rb
module ProofManageable
  extend ActiveSupport::Concern

  included do
    has_one_attached :income_proof
    has_one_attached :residency_proof

    validates :income_proof, :residency_proof,
      content_type: [ "application/pdf", "image/jpeg", "image/png" ],
      size: { less_than: 5.megabytes }

    after_attach :set_proof_status_to_unreviewed
  end

  def all_proofs_approved?
    income_proof_status_approved? && residency_proof_status_approved?
  end

  private

  def set_proof_status_to_unreviewed
    update(needs_review_since: Time.current) if income_proof.attached? || residency_proof.attached?
  end
end
