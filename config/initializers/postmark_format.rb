# Custom configuration for Postmark ActionMailer adapter
# This ensures our emails match the format of our successful curl request

if defined?(ActionMailer::Base)
  ActionMailer::Base.instance_eval do
    def postmark_settings
      {
        # Enable necessary features for email tracking while keeping payload clean
        return_response: true,
        track_opens: true,  # Enable open tracking for delivery confirmation
        track_links: "none"
      }
    end
  end
end
