class ApplicationMailbox < ActionMailbox::Base
  # Route emails from constituents for proof submissions
  routing(/proof@.*\.com/i => :proof_submission)

  # Route emails from medical professionals for certifications
  routing(/medical-cert@mdmat\.org/i => :medical_certification)

  # Default routing for unmatched emails
  routing(all: :default)
end
