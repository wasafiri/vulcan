class MedicalCertificationEmailJob < ApplicationJob
  queue_as :default
  retry_on Net::SMTPError, wait: :exponentially_longer, attempts: 3
  
  def perform(application_id:, timestamp:)
    Rails.logger.info "Processing medical certification email for application #{application_id}"
    
    application = Application.find(application_id)
    MedicalProviderMailer.request_certification(application).deliver_later
    
    Rails.logger.info "Successfully sent medical certification email for application #{application_id}"
  rescue StandardError => e
    Rails.logger.error "Failed to send certification email for application #{application_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    # Still raise to trigger retry mechanism
    raise
  end
end
