class WebhookRetryJob < ApplicationJob
  queue_as :webhooks
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(event_data)
    EmailEventHandler.new(event_data).process
  rescue StandardError => e
    Rails.logger.error("WebhookRetryJob failed: #{e.message}")
    Rails.error.report(e, context: { event_data: event_data })
    raise # Re-raise to trigger retry mechanism
  end
end
