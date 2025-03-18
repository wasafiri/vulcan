class MedicalProviderMailer < ApplicationMailer
  def request_certification(application, notification = nil)
    @application = application
    @constituent = application.user
    @notification = notification

    mail_options = {
      to: @application.medical_provider_email,
      subject: "Disability Certification Request for #{@constituent.full_name}",
      message_stream: "outbound"
    }

    # Send the mail through ActionMailer
    message = mail(mail_options)

    # Record the message ID if we have a notification to track
    if @notification.present? && message.delivery_method.is_a?(Mail::Postmark) && 
       message.delivery_handler.response.present?
      begin
        message_id = message.delivery_handler.response['MessageID']
        if message_id.present?
          @notification.update(message_id: message_id)
          UpdateEmailStatusJob.set(wait: 1.minute).perform_later(@notification.id)
        end
      rescue => e
        Rails.logger.error("Failed to record message ID: #{e.message}")
      end
    end
    
    # Do not return the response object, ActionMailer expects mail() to be the last line
  end
end
