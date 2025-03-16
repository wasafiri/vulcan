# Configure Active Storage to handle PDFs properly
Rails.application.config.active_storage.content_types_allowed_inline = [ "application/pdf" ]

# Configure Active Storage to serve PDFs with proper content disposition
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy

# Enable Rails' built-in direct upload functionality
# This automatically:
# - Mounts the direct upload endpoint at /rails/active_storage/direct_uploads
# - Handles CSRF protection
# - Manages blob creation and direct upload URLs
# - Provides consistent behavior across the application
Rails.application.config.active_storage.direct_upload = true
