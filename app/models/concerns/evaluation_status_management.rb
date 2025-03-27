# frozen_string_literal: true

module EvaluationStatusManagement
  extend ActiveSupport::Concern

  included do
    enum :status, {
      requested: 0,    # Initial evaluation requested
      scheduled: 1,    # Evaluation has been scheduled
      confirmed: 2,    # Constituent confirmed attendance
      completed: 3,    # Evaluation successfully completed
      cancelled: 4,    # Evaluation was cancelled
      rescheduled: 5,  # Evaluation has been rescheduled
      no_show: 6       # Constituent didn't show up
    }, prefix: true, validate: true

    scope :active, -> { where(status: %i[scheduled confirmed]) }
    scope :pending, -> { where(status: %i[scheduled confirmed]) }
    scope :completed_evaluations, -> { where(status: :completed) }
    scope :needing_followup, -> { where(status: %i[no_show cancelled]) }
    scope :requested_evaluations, -> { where(status: :requested) }
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

  def rescheduling?
    return false unless persisted? # New records aren't being rescheduled

    if evaluation_datetime_changed? && (status_changed? || status_scheduled?)
      # If the date is changing and we're either changing status to scheduled or already scheduled
      return true
    end

    false
  end
end
