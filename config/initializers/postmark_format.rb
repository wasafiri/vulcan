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
