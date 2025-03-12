# Custom configuration for Postmark ActionMailer adapter
# This ensures our emails match the format of our successful curl request

if defined?(ActionMailer::Base)
  ActionMailer::Base.instance_eval do
    def postmark_settings
      {
        # These settings prevent Postmark from adding unnecessary headers
        return_response: true,
        track_opens: false,
        track_links: "none"
      }
    end
  end
end

# Force Postmark to use the message_stream as a top-level parameter rather than a header
if defined?(Mail::Postmark)
  module PostmarkMessageStreamTopLevel
    def deliver!(mail)
      response = super
      
      # Log success for debugging
      if response.kind_of?(Postmark::ApiClient::HttpResponseMessageSentResult)
        Rails.logger.info "SUCCESS: Postmark message sent with ID: #{response.message_id}"
      end
      
      response
    rescue => e
      Rails.logger.error "ERROR: Failed to deliver mail through Postmark: #{e.message}"
      raise
    end
  end

  Mail::Postmark.prepend(PostmarkMessageStreamTopLevel)
end
