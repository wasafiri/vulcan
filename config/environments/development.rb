Rails.application.configure do
  config.eager_load = false

  # Only the non-default and required settings
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = { host: ENV['MAILER_HOST'] }

  config.action_mailer.smtp_settings = {
    address: 'smtp.elasticemail.com',
    port: 2525,
    user_name: 'apikey',
    password: ENV['ELASTIC_EMAIL_API_KEY'],
    authentication: :plain,
    enable_starttls_auto: true
  }

  config.active_job.queue_adapter = :solid_queue

  # Asset pipeline settings
  config.assets.debug = true
  config.assets.digest = true
  config.assets.raise_runtime_errors = true
end
