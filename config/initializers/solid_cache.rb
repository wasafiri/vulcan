if Rails.env.production?
  Rails.application.config.solid_cache.table_name_prefix = "cache."
end
