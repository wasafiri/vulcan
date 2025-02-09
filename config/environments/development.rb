Rails.application.configure do
  config.eager_load = false

  config.active_storage.service = :local

  # Only the non-default and required settings
  config.action_mailer.delivery_method = :letter_opener
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

  # config.active_job.queue_adapter = :solid_queue
  config.active_job.queue_adapter = :inline
  # config.solid_queue.connects_to = { database: { writing: :queue } }

  # Asset pipeline settings
  config.assets.debug = true
  config.assets.digest = true
  config.assets.raise_runtime_errors = true
  config.file_watcher = ActiveSupport::FileUpdateChecker
end
