# Configure Active Storage to handle PDFs properly
Rails.application.config.active_storage.content_types_allowed_inline = [ "application/pdf" ]

# Configure Active Storage to serve PDFs with proper content disposition
Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy

# Skip CSRF verification for direct uploads
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.skip_before_action :verify_authenticity_token
end
