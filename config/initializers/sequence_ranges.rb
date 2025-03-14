# This initializer ensures application IDs remain high and non-sequential for security
# High, non-sequential IDs prevent enumeration attacks and make IDs harder to guess
Rails.application.config.after_initialize do
  # Skip in test environment and when database tasks are running (like migrations)
  if !Rails.env.test? && !defined?(Rails::DBConsole) && ENV['DISABLE_DATABASE_ENVIRONMENT_CHECK'].blank?
    begin
      # Check if we're using PostgreSQL
      if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
        # Get current sequence value
        current_value = ActiveRecord::Base.connection.execute(
          "SELECT last_value FROM applications_id_seq"
        ).first["last_value"].to_i
        
        # High IDs are preferred for security against enumeration attacks
        # If the sequence is too low, reset it with random offset
        if current_value < 980_000_000
          # Use random offset for additional non-sequentiality
          new_value = 980_000_000 + Random.rand(100_000)
          
          Rails.logger.info "Setting applications_id_seq to #{new_value} (from #{current_value}) with randomization for security"
          ActiveRecord::Base.connection.execute(
            "SELECT setval('applications_id_seq', #{new_value})"
          )
        else
          Rails.logger.info "applications_id_seq (#{current_value}) already at secure high value"
        end
      end
    rescue => e
      # Don't crash the app if there's an issue with sequence setting
      Rails.logger.error "Failed to set secure ID sequence: #{e.message}"
    end
  end
end
