class Appointment < ApplicationRecord
  belongs_to :user, class_name: "Constituent"
  belongs_to :evaluator, class_name: "Evaluator", optional: true

  enum :appointment_type, { evaluation: 0, installation: 1, training: 2, troubleshooting: 3, retraining: 4 }

  validates :scheduled_for, presence: true
  validate :max_training_sessions_exceeded, on: :create

  private

  def max_training_sessions_exceeded
    return unless appointment_type == "training"

    max_sessions = Policy.get("max_training_sessions") || 3
    current_sessions = user.appointments.where(appointment_type: "training").count

    if current_sessions >= max_sessions
      errors.add(:base, "You have reached the maximum number of training sessions (#{max_sessions}).")
    end
  end
end
