class Evaluation < ApplicationRecord
  include EvaluationStatusManagement
  include NotificationDelivery

  belongs_to :evaluator, class_name: 'Evaluator'
  belongs_to :constituent, class_name: 'Constituent'
  belongs_to :application
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_and_belongs_to_many :recommended_products, class_name: 'Product', join_table: 'evaluations_products'

  enum :evaluation_type, { initial: 0, renewal: 1, special: 2 }
  
  # Simplified validations
  validates :evaluator, presence: true
  validates :reschedule_reason, presence: true, if: :rescheduling?
  validate :evaluator_must_be_evaluator_type
  validate :scheduled_time_must_be_future, on: :create

  # Conditional validations for completed status
  validates :evaluation_date,
            :location,
            :needs,
            :recommended_products,
            :attendees,
            :products_tried,
            :notes,
            presence: true,
            if: :status_completed?

  validate :validate_attendees_structure, if: :status_completed?
  validate :validate_products_tried_structure, if: :status_completed?
  validate :cannot_complete_without_notes, if: :will_save_change_to_status?

  # Callbacks
  before_save :set_completed_at, if: :status_changed_to_completed?
  before_save :ensure_status_schedule_consistency
  after_save :update_application_record, if: :saved_change_to_status?
  after_save :deliver_notifications, if: :should_deliver_notifications?

  # Define method used in controller
  def request_additional_info!
    update(status: :requested)
    Notification.create!(
      recipient: constituent,
      actor: evaluator,
      action: 'requested_additional_info',
      metadata: { evaluation_id: id },
      notifiable: self
    )
  end

  private

  def validate_attendees_structure
    return true unless status_completed?

    unless attendees.is_a?(Array) && attendees.all? { |attendee| attendee['name'].present? && attendee['relationship'].present? }
      errors.add(:attendees, 'must be an array of attendees with name and relationship when evaluation is completed')
    end
  end

  def validate_products_tried_structure
    return true unless status_completed?

    unless products_tried.is_a?(Array) && products_tried.all? { |product| product['product_id'].present? && product['reaction'].present? }
      errors.add(:products_tried, 'must be an array of products tried with product_id and reaction when evaluation is completed')
    end
  end

  def update_application_record
    return unless status_completed?

    application.update!(
      needs_review_since: nil
    )
    # Additional logic to handle post-evaluation actions
  end

  def evaluator_must_be_evaluator_type
    return if evaluator.nil? || evaluator.type == 'Evaluator'

    errors.add(:evaluator, 'must be an Evaluator')
  end
  
  def scheduled_time_must_be_future
    if evaluation_datetime.present? && evaluation_datetime <= Time.current
      errors.add(:evaluation_datetime, "must be in the future")
    end
  end

  def cannot_complete_without_notes
    if status_changed? && status_completed? && notes.blank?
      errors.add(:notes, "must be provided when completing evaluation")
    end
  end

  def set_completed_at
    self.evaluation_date = Time.current if status_completed? && evaluation_date.nil?
  end

  def status_changed_to_completed?
    status_completed? && status_changed?
  end

  def should_deliver_notifications?
    status_changed? || saved_change_to_evaluation_datetime?
  end
  
  def ensure_status_schedule_consistency
    # If setting a schedule date but still in requested status, update status
    if evaluation_datetime_changed? && evaluation_datetime.present? && status_requested?
      self.status = :scheduled
    end
    
    # If removing a schedule date but still in scheduled/confirmed status, prevent it
    if evaluation_datetime_changed? && evaluation_datetime.blank? && (status_scheduled? || status_confirmed?)
      errors.add(:evaluation_datetime, "cannot be removed while status is #{status}")
      throw(:abort)
    end
  end
end
