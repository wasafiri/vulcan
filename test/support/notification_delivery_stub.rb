# This file stubs out notification delivery methods for testing

# Stub NotificationJob and NotificationRetryJob
class NotificationJob
  def self.set(retry:)
    self
  end

  def self.perform_later(record)
    # Do nothing in tests
  end
end

class NotificationRetryJob
  def self.set(wait:)
    self
  end

  def self.perform_later(record)
    # Do nothing in tests
  end
end

module NotificationDeliveryStub
  def notify_status_change
    # Stub implementation for testing
    true
  end

  # Override deliver_notifications to avoid calling external services
  def deliver_notifications
    # Do nothing in tests
    true
  end
end

# Patch TrainingSession and Application for testing
TrainingSession.include(NotificationDeliveryStub) if defined?(TrainingSession)
Application.include(NotificationDeliveryStub) if defined?(Application)
