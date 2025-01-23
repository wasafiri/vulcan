class Evaluation < ApplicationRecord
  belongs_to :evaluator, class_name: "Evaluator"
  belongs_to :constituent, class_name: "Constituent"
  belongs_to :application

  has_many :notifications, as: :notifiable, dependent: :destroy

  enum :evaluation_type, { initial: 0, renewal: 1, special: 2 }
  enum :status, { pending: 0, completed: 1 }

  validates :evaluation_date, presence: true
  validates :evaluator, presence: true
  validate :evaluator_must_be_evaluator_type

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

  def evaluator_must_be_evaluator_type
    if evaluator && evaluator.type != "Evaluator"
      errors.add(:evaluator, "must be an Evaluator")
    end
  end
end
