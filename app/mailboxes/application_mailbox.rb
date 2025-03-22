class ApplicationMailbox < ActionMailbox::Base
  # Route emails to the specific Postmark inbound address
  routing ->(inbound_email) { 
    to_addresses = inbound_email.mail.to || []
    to_addresses.any? { |address| address.include?(MatVulcan::InboundEmailConfig.inbound_email_address) }
  } => :proof_submission
  
  # Route emails from constituents for proof submissions (backward compatibility)
  routing(/proof@.*\.com/i => :proof_submission)

  # Route emails from medical professionals for certifications
  routing(/medical-cert@mdmat\.org/i => :medical_certification)

  # Default routing for unmatched emails
  routing(all: :default)
end
