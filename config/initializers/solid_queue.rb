Rails.application.config.solid_queue.setup do |config|
  config.on_fatal_error do |error, job|
    if job.job_class == "WebhookRetryJob"
      Rails.error.report(
        error,
        context: {
          job_class: "WebhookRetryJob",
          arguments: job.arguments.first
        },
        severity: :error
      )
    end
  end

  config.queues.define do |queue|
    queue.default queue: :default
    queue.webhooks queue: :webhooks, concurrency: 5
  end
end
