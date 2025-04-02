# frozen_string_literal: true

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
    }, prefix: true, validate: true

    after_save :handle_status_change, if: :saved_change_to_status?
    after_save :auto_approve_if_eligible, if: :requirements_met_for_approval?

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
    scope :active, -> { where(status: %i[in_progress needs_information reminder_sent awaiting_documents]) }
    scope :draft, -> { where(status: :draft) }
    scope :submitted, -> { where.not(status: :draft) }
    scope :filter_by_status, ->(status) { where(status: status) if status.present? }
    scope :filter_by_type, lambda { |filter_type|
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
    scope :sorted_by, lambda { |column, direction|
      direction = direction&.downcase == 'desc' ? 'desc' : 'asc'

      if column.present?
        if column.start_with?('user.')
          association = 'users'
          column_name = column.split('.').last
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
    status_in_progress? || status_needs_information? || status_reminder_sent? || status_awaiting_documents?
  end

  def editable?
    status_draft?
  end

  def submitted?
    !status_draft?
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

  def requirements_met_for_approval?
    # Only run this when relevant fields have changed
    return false unless saved_change_to_income_proof_status? ||
                        saved_change_to_residency_proof_status? ||
                        saved_change_to_medical_certification_status?

    # Only auto-approve applications that aren't already approved
    return false if status_approved?

    # Check if all requirements are met
    all_requirements_met?
  end

  def all_requirements_met?
    income_proof_status_approved? &&
      residency_proof_status_approved? &&
      medical_certification_status_approved?
  end

  # Auto-approves the application when all requirements are met
  # Uses proper Rails update mechanisms to ensure audit trails are created
  def auto_approve_if_eligible
    previous_status = status
    update_application_status_to_approved
    create_auto_approval_audit_event(previous_status)
  end

  # Updates the application status using the model's status update method
  # This ensures proper status change records are created
  def update_application_status_to_approved
    update_status('approved', user: nil, notes: 'Auto-approved based on all requirements being met')
  end

  # Creates an audit event for the auto-approval
  def create_auto_approval_audit_event(previous_status)
    return unless defined?(Event) && Event.respond_to?(:create)
    
    begin
      Event.create!(
        user: nil,  # nil user indicates system action
        action: 'application_auto_approved',
        metadata: {
          application_id: id,
          old_status: previous_status,
          new_status: status,
          timestamp: Time.current.iso8601,
          auto_approval: true
        }
      )
    rescue StandardError => e
      # Log error but don't prevent the auto-approval
      Rails.logger.error("Failed to create event for auto-approval: #{e.message}")
    end
  end
end
