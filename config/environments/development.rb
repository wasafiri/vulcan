Rails.application.configure do
  config.eager_load = false

  config.active_storage.service = :local

  # Only the non-default and required settings
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = { host: ENV["MAILER_HOST"] }

  config.action_mailer.smtp_settings = {
    address: "smtp.elasticemail.com",
    port: 2525,
    user_name: "apikey",
    password: ENV["ELASTIC_EMAIL_API_KEY"],
    authentication: :plain,
    enable_starttls_auto: true
  }

  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Asset pipeline settings
  config.assets.debug = true
  config.assets.digest = true
  config.assets.raise_runtime_errors = true
  config.file_watcher = ActiveSupport::FileUpdateChecker
end
