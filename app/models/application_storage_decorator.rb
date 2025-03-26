# Decorator for Application objects to prevent unnecessary ActiveStorage eager loading
# when displaying attachments in views
class ApplicationStorageDecorator
  attr_reader :application
  
  def initialize(application)
    @application = application
    # Cache attachment metadata to avoid repeated DB queries
    @metadata_cache = {}
  end
  
  # Basic application attributes that should be delegated directly
  
  def id
    application.id
  end
  
  def application_date
    application.application_date
  end
  
  def user
    application.user
  end
  
  def status
    application.status
  end
  
  def income_proof_status
    application.income_proof_status
  end
  
  def residency_proof_status
    application.residency_proof_status
  end
  
  def medical_certification_status
    application.medical_certification_status
  end
  
  # ActiveStorage attachment accessors that avoid triggering eager loading
  
  # Direct access to attachments will use safe versions instead
  def income_proof
    self
  end
  
  def residency_proof
    self
  end
  
  def medical_certification
    self
  end
  
  # Attachment metadata access methods
  
  def filename
    # Used when an attachment method is called on our proxy attachment
    # For example: application.income_proof.filename
    attachment_metadata[:filename]
  end
  
  def content_type
    attachment_metadata[:content_type]
  end
  
  def byte_size
    attachment_metadata[:byte_size]
  end
  
  def attached?
    # Used as a fallback when the specific attachment method is not used
    # This should generally not be called directly
    raise "Use specific attachment methods instead (income_proof_attached?, residency_proof_attached?, etc.)"
  end
  
  # Safe method to check if income proof is attached without eager loading blob associations
  def income_proof_attached?
    if application.respond_to?(:income_proof_attachment_changes_to_save) &&
       application.income_proof_attachment_changes_to_save.present?
      true
    elsif application.association(:income_proof_attachment).loaded?
      application.income_proof_attachment.present?
    else
      attachment_exists?('income_proof')
    end
  end
  
  # Safe method to check if residency proof is attached without eager loading blob associations
  def residency_proof_attached?
    if application.respond_to?(:residency_proof_attachment_changes_to_save) &&
       application.residency_proof_attachment_changes_to_save.present?
      true
    elsif application.association(:residency_proof_attachment).loaded?
      application.residency_proof_attachment.present?
    else
      attachment_exists?('residency_proof')
    end
  end
  
  # Safe method to check if medical certification is attached without eager loading
  def medical_certification_attached?
    if application.respond_to?(:medical_certification_attachment_changes_to_save) &&
       application.medical_certification_attachment_changes_to_save.present?
      true
    elsif application.association(:medical_certification_attachment).loaded?
      application.medical_certification_attachment.present?
    else
      attachment_exists?('medical_certification')
    end
  end
  
  # Helper methods for fetching attachment data safely
  
  # Get attachment filename without blob access - useful for views
  def safe_income_proof_filename
    safe_attachment_attribute('income_proof', :filename)
  end
  
  def safe_residency_proof_filename
    safe_attachment_attribute('residency_proof', :filename)
  end
  
  # Get byte size without blob access
  def safe_income_proof_byte_size
    safe_attachment_attribute('income_proof', :byte_size)
  end
  
  def safe_residency_proof_byte_size
    safe_attachment_attribute('residency_proof', :byte_size)
  end
  
  # Current attachment context for metadata requests 
  def attachment_context=(context)
    @current_attachment_context = context
  end
  
  # Set when the decorator is used directly for attachment operations
  def attachment_context
    @current_attachment_context
  end
  
  private
  
  def attachment_exists?(name)
    @metadata_cache[:"#{name}_exists"] ||= ActiveStorage::Attachment.where(
      record_type: "Application",
      record_id: application.id,
      name: name
    ).exists?
  end
  
  def safe_attachment_attribute(name, attribute)
    return nil unless attachment_exists?(name)
    
    # Fetch from cache if available
    cache_key = :"#{name}_#{attribute}"
    return @metadata_cache[cache_key] if @metadata_cache.key?(cache_key)
    
    # Fetch metadata directly from the attachment record without loading the blob
    attachment = ActiveStorage::Attachment.select("id, name, record_id, blob_id, created_at, #{attribute}")
                                         .find_by(record_type: "Application", 
                                                  record_id: application.id, 
                                                  name: name)
    
    value = attachment&.send(attribute)
    @metadata_cache[cache_key] = value
    value
  end
  
  def attachment_metadata
    context = @current_attachment_context || 'unknown'
    Rails.logger.debug "Accessing attachment metadata for #{context} on application #{application.id}"
    
    # Return empty metadata for safety if context not set
    { filename: nil, content_type: nil, byte_size: 0 }
  end
  
  # Pass through method_missing to the original application for methods we don't override
  def method_missing(method_name, *args, &block)
    if application.respond_to?(method_name)
      application.send(method_name, *args, &block)
    else
      super
    end
  end
  
  def respond_to_missing?(method_name, include_private = false)
    application.respond_to?(method_name, include_private) || super
  end
end
