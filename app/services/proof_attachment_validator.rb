# frozen_string_literal: true

class ProofAttachmentValidator
  ALLOWED_MIME_TYPES = %w[
    application/pdf
    image/jpeg
    image/png
  ].freeze

  MAX_FILE_SIZE = 10.megabytes
  MIN_FILE_SIZE = 1.kilobyte

  class ValidationError < StandardError
    attr_reader :error_type

    def initialize(error_type, message)
      @error_type = error_type
      super(message)
    end
  end

  def self.validate!(attachment)
    new.validate!(attachment)
  end

  def validate!(attachment)
    validate(attachment)
  rescue ValidationError => e
    raise e
  rescue StandardError => e
    Rails.logger.error("Unexpected error in proof validation: #{e.message}")
    raise ValidationError.new(:unknown_error, 'An unexpected error occurred during validation')
  end

  def validate(attachment)
    return validation_error(:no_attachment, 'No attachment provided') if attachment.nil?

    attachment_size = get_attachment_size(attachment)

    if attachment_size < MIN_FILE_SIZE
      return validation_error(:file_too_small,
                              "File is too small (minimum #{MIN_FILE_SIZE} bytes)")
    end
    if attachment_size > MAX_FILE_SIZE
      return validation_error(:file_too_large,
                              "File is too large (maximum #{MAX_FILE_SIZE} bytes)")
    end
    return validation_error(:invalid_type, 'File type not allowed') unless valid_mime_type?(attachment)

    if potentially_malicious?(attachment)
      return validation_error(:suspicious_content,
                              'File contains suspicious content')
    end

    true
  end

  private

  def get_attachment_size(attachment)
    # Handle different attachment types (Mail::Part vs ActiveStorage::Blob)
    if attachment.respond_to?(:byte_size)
      # ActiveStorage::Blob or similar
      attachment.byte_size
    elsif attachment.respond_to?(:decoded)
      # Mail::Part - use decoded content size
      attachment.decoded.bytesize
    elsif attachment.respond_to?(:body) && attachment.body.respond_to?(:decoded)
      # Mail::Part with body.decoded
      attachment.body.decoded.bytesize
    else
      # Fallback - try to get size from content
      content = attachment.respond_to?(:read) ? attachment.read : attachment.to_s
      content.bytesize
    end
  end

  def validation_error(type, message)
    raise ValidationError.new(type, message)
  end

  def valid_mime_type?(attachment)
    ALLOWED_MIME_TYPES.include?(attachment.content_type)
  end

  def potentially_malicious?(attachment)
    filename = attachment.filename.to_s.downcase
    return true if suspicious_filename?(filename)
    return true if attachment.content_type == 'application/pdf' && pdf_malicious?(attachment)

    false
  end

  def suspicious_filename?(filename)
    filename.include?('..') ||
      filename.include?('/') ||
      filename.include?('\\') ||
      filename =~ /\.(exe|sh|bat|cmd|vbs|js)$/i
  end

  def pdf_malicious?(attachment)
    # Handle different attachment types when getting content for PDF analysis
    content = if attachment.respond_to?(:download)
                # ActiveStorage::Blob
                attachment.download.to_s
              elsif attachment.respond_to?(:decoded)
                # Mail::Part
                attachment.decoded.to_s
              elsif attachment.respond_to?(:body) && attachment.body.respond_to?(:decoded)
                # Mail::Part with body.decoded
                attachment.body.decoded.to_s
              else
                attachment.to_s
              end

    content.include?('/JS') ||
      content.include?('/JavaScript') ||
      content.include?('/Launch') ||
      content.include?('/SubmitForm') ||
      content.include?('/RichMedia')
  end

  def extract_content_type(attachment)
    Marcel::MimeType.for(
      attachment,
      name: attachment.filename.to_s,
      declared_type: attachment.content_type
    )
  end
end
