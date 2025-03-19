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
    }, validate: true

    scope :active, -> { where(status: %i[scheduled confirmed in_progress]) }
    scope :pending, -> { where(status: %i[scheduled confirmed]) }
    scope :completed_sessions, -> { where(status: :completed) }
    scope :needing_followup, -> { where(status: %i[no_show cancelled]) }
    scope :requested_sessions, -> { where(status: :requested) }
  end

  def active?
    scheduled? || confirmed? || in_progress?
  end

  def complete?
    completed?
  end

  def needs_followup?
    no_show? || cancelled?
  end

  def can_reschedule?
    cancelled? || no_show?
  end

  def can_cancel?
    scheduled? || confirmed?
  end

  def can_complete?
    in_progress?
  end
end
