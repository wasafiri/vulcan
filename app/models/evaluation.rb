class Evaluation < ApplicationRecord
  belongs_to :evaluator, class_name: 'Evaluator'
  belongs_to :constituent, class_name: 'Constituent'

  has_many :notifications, as: :notifiable, dependent: :destroy

  enum evaluation_type: { initial: 0, follow_up: 1, special: 2 }
  enum status: { pending: 0, completed: 1 }

  validates :evaluation_date, presence: true

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
end
