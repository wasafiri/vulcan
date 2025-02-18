Rails.application.configure do
  config.eager_load = false

  config.active_storage.service = :local

  # Configure Active Storage for PDF serving
  config.active_storage.content_types_allowed_inline = [ "application/pdf" ]
  config.active_storage.content_types_to_serve_as_binary = []

  # Configure default URL options
  Rails.application.routes.default_url_options = {
    host: "localhost",
    port: 3000
  }

  # Configure headers for PDF serving
  config.action_dispatch.default_headers = {
    "X-Frame-Options" => "SAMEORIGIN",
    "X-XSS-Protection" => "1; mode=block",
    "X-Content-Type-Options" => "nosniff",
    "X-Download-Options" => "noopen",
    "X-Permitted-Cross-Domain-Policies" => "none",
    "Referrer-Policy" => "strict-origin-when-cross-origin"
  }

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
