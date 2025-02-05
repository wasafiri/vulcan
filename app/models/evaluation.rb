class Evaluation < ApplicationRecord
  belongs_to :evaluator, class_name: "Evaluator"
  belongs_to :constituent, class_name: "Constituent"
  belongs_to :application
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_and_belongs_to_many :recommended_products, class_name: "Product", join_table: "evaluations_products"

  enum :evaluation_type, { initial: 0, renewal: 1, special: 2 }
  enum :status, { pending: 0, completed: 1 }

  # Simplified validations
  validates :evaluator, presence: true
  validate :evaluator_must_be_evaluator_type

  # Conditional validations for completed status
  validates :evaluation_date,
            :location,
            :needs,
            :recommended_products,
            :attendees,
            :products_tried,
            :notes,
            presence: true,
            if: :completed?

  validate :validate_attendees_structure, if: :completed?
  validate :validate_products_tried_structure, if: :completed?

  # Callbacks
  after_save :update_application_record, if: :saved_change_to_status?

  # Define method used in controller
  def request_additional_info!
    update(status: :pending)
    Notification.create!(
      recipient: constituent,
      actor: evaluator,
      action: "requested_additional_info",
      metadata: { evaluation_id: id },
      notifiable: self
    )
  end

  private

  def validate_attendees_structure
    return true unless completed?

    unless attendees.is_a?(Array) && attendees.all? { |attendee| attendee["name"].present? && attendee["relationship"].present? }
      errors.add(:attendees, "must be an array of attendees with name and relationship when evaluation is completed")
    end
  end

  def validate_products_tried_structure
    return true unless completed?

    unless products_tried.is_a?(Array) && products_tried.all? { |product| product["product_id"].present? && product["reaction"].present? }
      errors.add(:products_tried, "must be an array of products tried with product_id and reaction when evaluation is completed")
    end
  end

  def update_application_record
    if completed?
      application.update!(
        needs_review_since: nil,
      )
      # Additional logic to handle post-evaluation actions
    end
  end

  def evaluator_must_be_evaluator_type
    if evaluator && evaluator.type != "Evaluator"
      errors.add(:evaluator, "must be an Evaluator")
    end
  end
end
