# app/jobs/email_verification_job.rb
class EmailVerificationJob < ApplicationJob
  queue_as :default

  def perform(medical_provider_email)
    # Basic format validation
    unless medical_provider_email.email.match?(URI::MailTo::EMAIL_REGEXP)
      medical_provider_email.update(status: :failed)
      return
    end

    # Check MX records
    domain = medical_provider_email.email.split("@").last
    Resolv::DNS.open do |dns|
      mx_records = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)

      if mx_records.empty?
        medical_provider_email.update(status: :failed)
        return
      end
    end

    # If we get here, the email format is valid and MX records exist
    medical_provider_email.update(status: :verified)
  rescue StandardError => e
    Rails.logger.error "Email verification failed: #{e.message}"
    medical_provider_email.update(status: :failed)
  end
end
