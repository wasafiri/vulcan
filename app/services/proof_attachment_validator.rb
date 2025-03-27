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

    if attachment.byte_size < MIN_FILE_SIZE
      return validation_error(:file_too_small,
                              "File is too small (minimum #{MIN_FILE_SIZE} bytes)")
    end
    if attachment.byte_size > MAX_FILE_SIZE
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
    content = attachment.download.to_s
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
