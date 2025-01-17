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
      archived: 7            # Historical record
  }, validate: true
  end

  def active?
    in_progress? || needs_information? || reminder_sent? || awaiting_documents?
  end

  def editable?
    draft?
  end

  def submitted?
    !draft?
  end
end
