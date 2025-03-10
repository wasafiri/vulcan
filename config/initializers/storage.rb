# Configure Active Storage service based on environment
Rails.application.config.to_prepare do
  Rails.application.config.active_storage.service = 
    case Rails.env
    when 'test'
      :test
    when 'development'
      ENV['USE_S3'] == 'true' ? :s3 : :local
    else
      :s3
    end
end
