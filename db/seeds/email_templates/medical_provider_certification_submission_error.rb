# frozen_string_literal: true

# Seed File for "medical_provider_certification_submission_error"
EmailTemplate.create_or_find_by!(name: 'medical_provider_certification_submission_error', format: :text) do |template|
  template.subject = 'Medical Certification Submission Error'
  template.description = 'Sent to a medical provider when an error occurs during the automated processing of their submitted certification form.'
  template.body = <<~TEXT
    Medical Certification Submission Error

    Dear Medical Provider,

    We encountered an error processing your recent medical certification submission from %<medical_provider_email>s.

    The error message is: %<error_message>s

    Please review the error and resubmit the certification form to medical-certification@maryland.gov or by fax to (410) 767-4276.

    If you continue to experience issues or have questions, please contact us at medical-cert@mdmat.org or call 410-767-6960.

    Sincerely,
    Maryland Accessible Telecommunications Program

    ---

    This is an automated message. Please do not reply directly to this email.
  TEXT
  template.variables = %w[medical_provider_email error_message]
  template.version = 1
end
Rails.logger.debug 'Seeded medical_provider_certification_submission_error (text)' if ENV['VERBOSE_TESTS'] || Rails.env.development?
