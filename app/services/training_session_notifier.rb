class TrainingSessionNotifier
  attr_reader :training_session

  def initialize(training_session)
    @training_session = training_session
  end

  def deliver_all
    return unless should_send_notification?

    ActiveRecord::Base.transaction do
      send_email_notifications
      create_in_app_notifications
    end
  end

  private

  def should_send_notification?
    training_session.status_changed? ||
    training_session.saved_change_to_scheduled_for? ||
    training_session.saved_change_to_completed_at?
  end

  def send_email_notifications
    case training_session.status
    when "scheduled", "confirmed"
      TrainingSessionNotificationsMailer.training_scheduled(training_session).deliver_now
    when "completed"
      TrainingSessionNotificationsMailer.training_completed(training_session).deliver_now
    when "cancelled"
      TrainingSessionNotificationsMailer.training_cancelled(training_session).deliver_now
    when "no_show"
      TrainingSessionNotificationsMailer.no_show_notification(training_session).deliver_now
    end
  end

  def create_in_app_notifications
    Notification.create!(
      recipient: training_session.constituent,
      actor: training_session.trainer,
      action: notification_action,
      notifiable: training_session,
      metadata: notification_metadata
    )
  end

  def notification_action
    case training_session.status
    when "scheduled", "confirmed" then "training_scheduled"
    when "completed" then "training_completed"
    when "cancelled" then "training_cancelled"
    when "no_show" then "training_missed"
    else "training_updated"
    end
  end

  def notification_metadata
    {
      training_session_id: training_session.id,
      application_id: training_session.application.id,
      status: training_session.status,
      scheduled_for: training_session.scheduled_for&.iso8601,
      completed_at: training_session.completed_at&.iso8601,
      trainer_name: training_session.trainer.full_name,
      timestamp: Time.current.iso8601
    }
  end
end
