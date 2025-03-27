# frozen_string_literal: true

module TrainingStatusManagement
  extend ActiveSupport::Concern

  included do
    enum :status, {
      requested: 0,     # Training initially requested, needs scheduling
      scheduled: 1,     # Training session has been scheduled
      confirmed: 2,     # Constituent confirmed attendance
      completed: 3,     # Training successfully completed
      cancelled: 4,     # Training was cancelled
      rescheduled: 5,   # Training has been rescheduled
      no_show: 6        # Constituent didn't show up
    }, prefix: true, validate: true

    scope :active, -> { where(status: %i[scheduled confirmed]) }
    scope :pending, -> { where(status: %i[scheduled confirmed]) }
    scope :completed_sessions, -> { where(status: :completed) }
    scope :needing_followup, -> { where(status: %i[no_show cancelled]) }
    scope :requested_sessions, -> { where(status: :requested) }
  end

  def active?
    status_scheduled? || status_confirmed?
  end

  def complete?
    status_completed?
  end

  def needs_followup?
    status_no_show? || status_cancelled?
  end

  def can_reschedule?
    status_cancelled? || status_no_show?
  end

  def can_cancel?
    status_scheduled? || status_confirmed?
  end

  def can_complete?
    status_scheduled? || status_confirmed?
  end
end
