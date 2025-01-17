module TrainingStatusManagement
  extend ActiveSupport::Concern

  included do
    enum :status, {
      scheduled: 0,     # Training session has been scheduled
      confirmed: 1,     # Constituent confirmed attendance
      completed: 2,     # Training successfully completed
      cancelled: 3,     # Training was cancelled
      rescheduled: 4,   # Training has been rescheduled
      no_show: 5        # Constituent didn't show up
    }, validate: true

    scope :active, -> { where(status: [ :scheduled, :confirmed, :in_progress ]) }
    scope :pending, -> { where(status: [ :scheduled, :confirmed ]) }
    scope :completed_sessions, -> { where(status: :completed) }
    scope :needing_followup, -> { where(status: [ :no_show, :cancelled ]) }
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
