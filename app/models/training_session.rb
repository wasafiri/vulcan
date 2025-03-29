# frozen_string_literal: true

class TrainingSession < ApplicationRecord
  include TrainingStatusManagement
  include NotificationDelivery

  # Associations
  belongs_to :application
  belongs_to :trainer, class_name: 'User'
  has_one :constituent, through: :application, source: :user

  # Validations
  validates :scheduled_for, presence: true, unless: :status_requested?
  validates :trainer, presence: true
  validates :application, presence: true
  validates :reschedule_reason, presence: true, if: :rescheduling?
  validate :trainer_must_be_trainer_type
  validate :scheduled_time_must_be_future, on: :create
  validate :cannot_complete_without_notes, if: :will_save_change_to_completed_at?

  # Callbacks
  before_save :set_completed_at, if: :status_changed_to_completed?
  before_save :ensure_status_schedule_consistency
  after_save :deliver_notifications, if: :saved_change_to_status?

  def rescheduling?
    return false unless persisted? # New records aren't being rescheduled

    if scheduled_for_changed? && (status_changed? || status_scheduled?)
      # If the date is changing and we're either changing status to scheduled or already scheduled
      return true
    end

    false
  end

  private

  def trainer_must_be_trainer_type
    return if trainer&.type == 'Users::Trainer'

    errors.add(:trainer, 'must be a trainer')
  end

  def scheduled_time_must_be_future
    return unless scheduled_for.present? && scheduled_for <= Time.current

    errors.add(:scheduled_for, 'must be in the future')
  end

  def cannot_complete_without_notes
    return unless notes.blank?

    errors.add(:notes, 'must be provided when completing training')
  end

  def set_completed_at
    self.completed_at = Time.current if status_completed? && completed_at.nil?
  end

  def status_changed_to_completed?
    status_completed? && status_changed?
  end

  def should_deliver_notifications?
    status_changed? || saved_change_to_scheduled_for? || saved_change_to_completed_at?
  end

  def ensure_status_schedule_consistency
    # If setting a schedule date but still in requested status, update status
    self.status = :scheduled if scheduled_for_changed? && scheduled_for.present? && status_requested?

    # If removing a schedule date but still in scheduled/confirmed status, prevent it
    return unless scheduled_for_changed? && scheduled_for.blank? && (status_scheduled? || status_confirmed?)

    errors.add(:scheduled_for, "cannot be removed while status is #{status}")
    throw(:abort)
  end
end
