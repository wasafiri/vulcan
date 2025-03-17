module ApplicationStatusManagement
  extend ActiveSupport::Concern

  included do
    enum :status, {
      draft: 0,               # Constituent still working on application
      in_progress: 1,         # Submitted by constituent, being processed
      approved: 2,            # Application approved
      rejected: 3,            # Application rejected
      needs_information: 4,   # Additional info needed from constituent
      reminder_sent: 5,       # Reminder sent to constituent
      awaiting_documents: 6,  # Waiting for specific documents
      archived: 7             # Historical record
    }, validate: true

    after_save :handle_status_change, if: :saved_change_to_status?

    enum :application_type, {
      new: 0,
      renewal: 1
    }, prefix: true

    enum :submission_method, {
      online: 0,
      paper: 1,
      phone: 2,
      email: 3
    }, prefix: true

    enum :income_verification_status, {
      pending: 0,
      verified: 1,
      failed: 2
    }, prefix: true

    # Status-related scopes
    scope :active, -> { where(status: [ :in_progress, :needs_information, :reminder_sent, :awaiting_documents ]) }
    scope :draft, -> { where(status: :draft) }
    scope :submitted, -> { where.not(status: :draft) }
    scope :filter_by_status, ->(status) { where(status: status) if status.present? }
    scope :filter_by_type, ->(filter_type) {
       case filter_type
       when 'proofs_needing_review'
         where(
           'income_proof_status = ? OR residency_proof_status = ?',
           income_proof_statuses[:not_reviewed],
           residency_proof_statuses[:not_reviewed]
         )
       when 'proofs_rejected'
         where(
           income_proof_status: income_proof_statuses[:rejected],
           residency_proof_status: residency_proof_statuses[:rejected]
         )
       when 'awaiting_medical_response'
         where(status: statuses[:awaiting_documents])
       end
     }
     scope :sorted_by, ->(column, direction) {
      direction = direction&.downcase == 'desc' ? 'desc' : 'asc'

      if column.present?
        if column.start_with?('user.')
          association = 'users'
          column_name = column.split(".").last
          joins(:user).order("#{association}.#{column_name} #{direction}")
        elsif column_names.include?(column)
          order("#{column} #{direction}")
        else
          order(application_date: :desc)
        end
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

  private

  def handle_status_change
    return unless status_previously_changed?(to: 'awaiting_documents')

    handle_awaiting_documents_transition
  end

  def handle_awaiting_documents_transition
    return unless all_proofs_approved?
    return if medical_certification_status_requested?

    # Update certification status and send email
    with_lock do
      update!(medical_certification_status: :requested)
      MedicalProviderMailer.request_certification(self).deliver_later
    end
  end
end
