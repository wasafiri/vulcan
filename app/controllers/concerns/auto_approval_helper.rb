# frozen_string_literal: true

# Provides methods for handling application auto-approval conditions
# Can be included in controllers that need to check or trigger auto-approval
module AutoApprovalHelper
  extend ActiveSupport::Concern

  # Determines if auto-approval conditions are met for an application
  # @param application [Application] The application to check
  # @param status [Symbol] The new status being applied (typically for proofs/certifications)
  # @return [Boolean] True if conditions for auto-approval are met
  def should_auto_approve?(application, status)
    (status == :approved) && 
      application.income_proof_status_approved? && 
      application.residency_proof_status_approved? &&
      !application.status_approved?
  end
  
  # Performs application auto-approval
  # @param application [Application] The application to approve
  def perform_auto_approval(application)
    Rails.logger.info "Auto-approval conditions met but application was not auto-approved."
    Rails.logger.info "Manually triggering approval for application #{application.id}"
    
    # Ensure we have fresh data
    application.reload
    application.approve!
  end
end
