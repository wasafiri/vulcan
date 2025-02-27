if Rails.env.production?
  # Set table names individually for SolidCache models
  SolidCache::Entry.table_name = "cache.entries"
end
