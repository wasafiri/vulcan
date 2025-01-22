module ApplicationStatusManagement
  extend ActiveSupport::Concern

  included do
    enum :status, {
      draft: 0,              # Constituent still working on application
      in_progress: 1,        # Submitted by constituent, being processed
      approved: 2,           # Application approved
      rejected: 3,           # Application rejected
      needs_information: 4,  # Additional info needed from constituent
      reminder_sent: 5,      # Reminder sent to constituent
      awaiting_documents: 6, # Waiting for specific documents
      archived: 7           # Historical record
    }, validate: true

    # Status-related scopes
    scope :active, -> { where(status: [ :in_progress, :needs_information, :reminder_sent, :awaiting_documents ]) }
    scope :draft, -> { where(status: :draft) }
    scope :submitted, -> { where.not(status: :draft) }
    scope :filter_by_status, ->(status) { where(status: status) if status.present? }
    scope :filter_by_type, ->(filter_type) {
      case filter_type
      when "proofs_needing_review"
        where("income_proof_status = ? OR residency_proof_status = ?", "not_reviewed", "not_reviewed")
      when "proofs_rejected"
        where(income_proof_status: :rejected, residency_proof_status: :rejected)
      when "awaiting_medical_response"
        where(status: :awaiting_documents)
      end
    }
    scope :sorted_by, ->(column, direction) {
      if column.present? && column_names.include?(column)
        order("#{column} #{direction || 'asc'}")
      else
        order(application_date: :desc)
      end
    }
  end

  # Status check methods
  def active?
    in_progress? || needs_information? || reminder_sent? || awaiting_documents?
  end

  def editable?
    draft?
  end

  def submitted?
    !draft?
  end

  # Status update methods
  def approve!
    update!(status: :approved)
  end

  def reject!
    update!(status: :rejected)
  end

  def request_documents!
    update!(status: :awaiting_documents)
  end

  def self.batch_update_status(ids, status)
    where(id: ids).update_all(status: status)
  end
end
