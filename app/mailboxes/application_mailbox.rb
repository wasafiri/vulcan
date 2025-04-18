# frozen_string_literal: true

class ApplicationMailbox < ActionMailbox::Base
  # Order matters: More specific routes first.

  # Use lambdas with direct string comparison for robustness
  routing ->(inbound_email) { (inbound_email.mail.to || []).include?('medical-cert@mdmat.org') } => :medical_certification
  routing ->(inbound_email) { (inbound_email.mail.to || []).include?('proof@example.com') } => :proof_submission
  routing lambda { |inbound_email|
    (inbound_email.mail.to || []).include?(MatVulcan::InboundEmailConfig.inbound_email_address)
  } => :proof_submission

  # Default routing for unmatched emails
  routing(all: :default)
end
