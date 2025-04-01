# frozen_string_literal: true

# Service for sending faxes through Twilio
class FaxService
  class FaxError < StandardError; end

  def initialize
    @account_sid = Rails.application.config.twilio[:account_sid]
    @auth_token = Rails.application.config.twilio[:auth_token]
    @fax_from_number = Rails.application.config.twilio[:fax_from_number]
    
    # Setup Twilio client if credentials are available
    if @account_sid.present? && @auth_token.present?
      @client = Twilio::REST::Client.new(@account_sid, @auth_token)
    else
      Rails.logger.warn 'Twilio credentials not configured. Fax service will not be available.'
      @client = nil
    end
  end

  # Send a fax with the given media URL and to the specified fax number
  # @param to [String] The recipient fax number
  # @param media_url [String] URL of the document to fax
  # @param options [Hash] Additional options like quality, status_callback, etc.
  # @return [Twilio::REST::Fax::V1::FaxInstance, nil] The fax instance if successful
  def send_fax(to:, media_url:, options: {})
    unless @client
      Rails.logger.error 'Cannot send fax: Twilio client not initialized'
      return nil
    end

    unless valid_fax_number?(to)
      Rails.logger.error "Invalid fax number: #{to}"
      return nil
    end

    from = options[:from] || @fax_from_number
    unless valid_fax_number?(from)
      Rails.logger.error "Invalid from fax number: #{from}"
      return nil
    end

    begin
      # Format the fax numbers with + prefix if needed
      to_formatted = format_fax_number(to)
      from_formatted = format_fax_number(from)

      # Default options
      fax_options = {
        from: from_formatted,
        to: to_formatted,
        media_url: media_url,
        status_callback: options[:status_callback]
      }

      # Add optional parameters if provided
      fax_options[:quality] = options[:quality] if options[:quality].present?
      fax_options[:sip_auth_username] = options[:sip_auth_username] if options[:sip_auth_username].present?
      fax_options[:sip_auth_password] = options[:sip_auth_password] if options[:sip_auth_password].present?

      # Send the fax
      fax = @client.fax.faxes.create(fax_options)
      Rails.logger.info "Fax sent successfully. SID: #{fax.sid}, Status: #{fax.status}"
      
      # Return the fax instance
      fax
    rescue Twilio::REST::RestError => e
      Rails.logger.error "Twilio error sending fax: #{e.message} (Code: #{e.code})"
      raise FaxError, "Failed to send fax: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Error sending fax: #{e.message}"
      raise FaxError, "Failed to send fax: #{e.message}"
    end
  end

  # Send a fax with a PDF document
  # @param to [String] The recipient fax number
  # @param pdf_path [String] Path to the PDF file to fax
  # @param options [Hash] Additional options for sending the fax
  # @return [Twilio::REST::Fax::V1::FaxInstance, nil] The fax instance if successful
  def send_pdf_fax(to:, pdf_path:, options: {})
    # Validate the PDF exists and is accessible
    unless File.exist?(pdf_path)
      Rails.logger.error "PDF file not found: #{pdf_path}"
      return nil
    end

    # For a real implementation, we would need to:
    # 1. Upload the PDF to a publicly accessible URL (S3, etc.)
    # 2. Get the URL of the uploaded file
    # 3. Send the fax using that URL
    
    # In production, implement S3 upload or another storage solution
    # For now, we'll assume the PDF is already at a URL
    media_url = options[:media_url] || "file://#{pdf_path}"
    
    # Call the regular send_fax method
    send_fax(to: to, media_url: media_url, options: options)
  end

  # Check the status of a fax
  # @param fax_sid [String] The SID of the fax to check
  # @return [String, nil] The status of the fax or nil if an error occurred
  def check_fax_status(fax_sid)
    return nil unless @client

    begin
      fax = @client.fax.faxes(fax_sid).fetch
      fax.status
    rescue Twilio::REST::RestError => e
      Rails.logger.error "Twilio error checking fax status: #{e.message} (Code: #{e.code})"
      nil
    rescue StandardError => e
      Rails.logger.error "Error checking fax status: #{e.message}"
      nil
    end
  end

  private

  # Validate that the fax number is in a proper format
  # @param number [String] The fax number to validate
  # @return [Boolean] Whether the number is valid
  def valid_fax_number?(number)
    return false unless number.present?
    
    # Remove any non-digit characters except +
    cleaned_number = number.to_s.gsub(/[^\d+]/, '')
    
    # Check if the number starts with + followed by digits, or just digits
    cleaned_number.match?(/^\+?\d{10,15}$/)
  end

  # Format a fax number to ensure it starts with +
  # @param number [String] The fax number to format
  # @return [String] The formatted fax number
  def format_fax_number(number)
    return nil unless number.present?
    
    # Remove any non-digit characters except +
    cleaned_number = number.to_s.gsub(/[^\d+]/, '')
    
    # Ensure it starts with +
    cleaned_number.start_with?('+') ? cleaned_number : "+#{cleaned_number}"
  end
end
