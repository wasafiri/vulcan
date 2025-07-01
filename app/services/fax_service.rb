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
    return nil unless validate_client_and_numbers(to, options)

    begin
      fax_options = build_fax_options(to, media_url, options)
      send_fax_request(fax_options)
    rescue Twilio::REST::RestError => e
      handle_twilio_error(e)
    rescue StandardError => e
      handle_standard_error(e)
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

  # Validate client initialization and fax numbers
  # @param to [String] The recipient fax number
  # @param options [Hash] Additional options containing from number
  # @return [Boolean] Whether validation passed
  def validate_client_and_numbers(to, options)
    return false unless validate_client_initialized?
    return false unless validate_recipient_number?(to)

    validate_sender_number?(options[:from] || @fax_from_number)
  end

  # Validate that Twilio client is initialized
  # @return [Boolean] Whether client is valid
  def validate_client_initialized?
    return true if @client

    Rails.logger.error 'Cannot send fax: Twilio client not initialized'
    false
  end

  # Validate recipient fax number
  # @param to [String] The recipient fax number
  # @return [Boolean] Whether number is valid
  def validate_recipient_number?(to)
    return true if valid_fax_number?(to)

    Rails.logger.error "Invalid fax number: #{to}"
    false
  end

  # Validate sender fax number
  # @param from [String] The sender fax number
  # @return [Boolean] Whether number is valid
  def validate_sender_number?(from)
    return true if valid_fax_number?(from)

    Rails.logger.error "Invalid from fax number: #{from}"
    false
  end

  # Build the options hash for the fax request
  # @param to [String] The recipient fax number
  # @param media_url [String] URL of the document to fax
  # @param options [Hash] Additional options
  # @return [Hash] The formatted options for Twilio
  def build_fax_options(to, media_url, options)
    from = options[:from] || @fax_from_number

    base_options = {
      from: format_fax_number(from),
      to: format_fax_number(to),
      media_url: media_url,
      status_callback: options[:status_callback]
    }

    add_optional_parameters(base_options, options)
  end

  # Add optional parameters to fax options
  # @param fax_options [Hash] The base fax options
  # @param options [Hash] Additional options to merge
  # @return [Hash] The updated fax options
  def add_optional_parameters(fax_options, options)
    optional_params = %i[quality sip_auth_username sip_auth_password]

    optional_params.each do |param|
      fax_options[param] = options[param] if options[param].present?
    end

    fax_options
  end

  # Send the actual fax request to Twilio
  # @param fax_options [Hash] The formatted options for the fax
  # @return [Twilio::REST::Fax::V1::FaxInstance] The fax instance
  def send_fax_request(fax_options)
    fax = @client.fax.faxes.create(fax_options)
    Rails.logger.info "Fax sent successfully. SID: #{fax.sid}, Status: #{fax.status}"
    fax
  end

  # Handle Twilio-specific errors
  # @param error [Twilio::REST::RestError] The Twilio error
  def handle_twilio_error(error)
    Rails.logger.error "Twilio error sending fax: #{error.message} (Code: #{error.code})"
    raise FaxError, "Failed to send fax: #{error.message}"
  end

  # Handle standard errors
  # @param error [StandardError] The standard error
  def handle_standard_error(error)
    Rails.logger.error "Error sending fax: #{error.message}"
    raise FaxError, "Failed to send fax: #{error.message}"
  end

  # Validate that the fax number is in a proper format
  # @param number [String] The fax number to validate
  # @return [Boolean] Whether the number is valid
  def valid_fax_number?(number)
    return false if number.blank?

    # Remove any non-digit characters except +
    cleaned_number = number.to_s.gsub(/[^\d+]/, '')

    # Check if the number starts with + followed by digits, or just digits
    cleaned_number.match?(/^\+?\d{10,15}$/)
  end

  # Format a fax number to ensure it starts with +
  # @param number [String] The fax number to format
  # @return [String] The formatted fax number
  def format_fax_number(number)
    return nil if number.blank?

    # Remove any non-digit characters except +
    cleaned_number = number.to_s.gsub(/[^\d+]/, '')

    # Ensure it starts with +
    cleaned_number.start_with?('+') ? cleaned_number : "+#{cleaned_number}"
  end
end
