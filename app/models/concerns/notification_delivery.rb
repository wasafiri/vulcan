module NotificationDelivery
  extend ActiveSupport::Concern

  included do
    after_create_commit :deliver_notifications
  end

  def deliver_notifications
    return unless should_deliver_notifications?

    begin
      if Rails.configuration.use_job_scheduler
        # New job-based delivery while preserving retry logic
        NotificationJob.set(retry: 3).perform_later(self)
      else
        # Existing robust delivery logic
        ApplicationNotifier.new(self).deliver_all
      end
    rescue => e
      log_delivery_error(e)
      retry_delivery_later
    end
  end

  private

  def should_deliver_notifications?
    status_changed? ||
      (respond_to?(:income_proof_status_changed?) && income_proof_status_changed?) ||
      (respond_to?(:residency_proof_status_changed?) && residency_proof_status_changed?)
  end

  def log_delivery_error(error)
    Rails.logger.error("Notification delivery failed: #{error.message}")
    Rails.logger.error("Record: #{self.class.name}, ID: #{id}")
    Rails.logger.error("Error details: #{error.backtrace.join("\n")}")
  end

  def retry_delivery_later
    NotificationRetryJob.set(wait: 5.minutes).perform_later(self)
  end
end
