class TrainingSession < ApplicationRecord
  include TrainingStatusManagement

  # Associations
  belongs_to :application
  belongs_to :trainer, class_name: "User"
  has_one :constituent, through: :application, source: :user

  # Validations
  validates :scheduled_for, presence: true
  validates :trainer, presence: true
  validates :application, presence: true
  validate :trainer_must_be_trainer_type
  validate :scheduled_time_must_be_future, on: :create
  validate :cannot_complete_without_notes, if: :will_save_change_to_completed_at?

  # Callbacks
  before_save :set_completed_at, if: :status_changed_to_completed?
  after_save :notify_status_change, if: :saved_change_to_status?

  private

  def trainer_must_be_trainer_type
    unless trainer&.type == "Trainer"
      errors.add(:trainer, "must be a trainer")
    end
  end

  def scheduled_time_must_be_future
    if scheduled_for.present? && scheduled_for <= Time.current
      errors.add(:scheduled_for, "must be in the future")
    end
  end

  def cannot_complete_without_notes
    if notes.blank?
      errors.add(:notes, "must be provided when completing training")
    end
  end

  def set_completed_at
    self.completed_at = Time.current if completed? && completed_at.nil?
  end

  def status_changed_to_completed?
    completed? && status_changed?
  end

  include NotificationDelivery

  private

  def should_deliver_notifications?
    status_changed? || saved_change_to_scheduled_for? || saved_change_to_completed_at?
  end
end
