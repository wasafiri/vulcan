# frozen_string_literal: true

# Enhanced debugging for Postmark client to log request payload
# This will help diagnose the difference between curl and Rails mail formatting

if defined?(Postmark::HttpClient)
  module PostmarkDebugger
    def post(path, data = {})
      # Log the original data being sent to Postmark
      Rails.logger.info "POSTMARK PAYLOAD (ORIGINAL): #{data.to_json}"

      # If this is an email, simplify the payload to match our successful curl request
      if path == '/email' && data.is_a?(Hash)
        # Ensure MessageStream is a top-level parameter, not a header
        if data['Headers']&.any? { |h| h['Name'] == 'X-PM-Message-Stream' }
          stream_header = data['Headers'].find { |h| h['Name'] == 'X-PM-Message-Stream' }
          data['MessageStream'] = stream_header['Value'] if stream_header
          data['Headers'].delete_if { |h| h['Name'] == 'X-PM-Message-Stream' }
        end

        # Always remove ReplyTo field to match our successful curl request
        data.delete('ReplyTo')

        # Simplify Headers to match our curl request
        if data['Headers']&.any?
          # Keep only essential headers
          data['Headers'].select! do |header|
            %w[Message-ID Content-Type].include?(header['Name'])
          end

          # Remove Headers entirely if empty
          data.delete('Headers') if data['Headers'].empty?
        end

        # Log the modified payload
        Rails.logger.info "POSTMARK PAYLOAD (MODIFIED): #{data.to_json}"
      end

      # Call the original method
      super
    end

    # Simple error logging without trying to inspect the response type
    def handle_response(response)
      result = super
      Rails.logger.info 'POSTMARK SUCCESS: Email sent successfully'
      result
    rescue StandardError => e
      Rails.logger.error "POSTMARK ERROR: #{e.class} - #{e.message}"
      raise
    end
  end

  Postmark::HttpClient.prepend(PostmarkDebugger)
end
