if Rails.env.production?
  Rails.application.config.solid_queue.table_name_prefix = "queue."
end
