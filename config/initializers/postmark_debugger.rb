# Monkey-patch Postmark client to log request payload
# This will help diagnose the difference between curl and Rails mail formatting

if defined?(Postmark::HttpClient)
  module PostmarkDebugger
    def post(path, data = {})
      # Log the data being sent to Postmark
      Rails.logger.info "POSTMARK PAYLOAD: #{data.to_json}"
      super
    end
  end

  Postmark::HttpClient.prepend(PostmarkDebugger)
end
