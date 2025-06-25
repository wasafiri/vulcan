# frozen_string_literal: true

require 'test_helper'

class PaperApplicationContextTest < ActionDispatch::IntegrationTest
  setup do
    @constituent = FactoryBot.create(:constituent)
    @application = FactoryBot.create(:application,
                                     user: @constituent,
                                     status: :in_progress,
                                     submission_method: :online, # Start as online to ensure validations normally run
                                     income_proof_status: :approved, # Status requires attachment
                                     residency_proof_status: :approved) # Status requires attachment
    # Ensure no proofs are actually attached initially
    @application.income_proof.detach
    @application.residency_proof.detach
  end

  test 'proof validations are enforced without paper application context' do
    # Attempt to save the application - should fail ProofConsistencyValidation
    # because proofs are approved but not attached.
    assert_not @application.save, 'Application should fail validation without attached proofs when status is approved'

    # Check specific errors (adjust based on exact validation message)
    assert_includes @application.errors[:income_proof], 'must be attached when status is approved'
    assert_includes @application.errors[:residency_proof], 'must be attached when status is approved'

    # Verify ProofManageable validation also fails if applicable (e.g., verify_proof_attachments)
    # Note: ProofConsistencyValidation might catch it first.
    # We primarily want to ensure *some* proof validation fails here.
    proof_errors = @application.errors.to_hash.keys.select { |k| k.to_s.include?('proof') }
    assert_not_empty proof_errors, 'Expected proof-related validation errors'
  end

  test 'proof validations are skipped within paper application context' do
    # Wrap the save attempt in the paper application context
    # This simulates how the CreateOrUpdateCommand will operate
    saved_successfully = false
    begin
      setup_paper_application_context
      # Attempt to save the application again. It should now succeed because
      # ProofConsistencyValidation and ProofManageable checks are bypassed.
      saved_successfully = @application.save
    ensure
      teardown_paper_application_context # Ensure cleanup
    end

    assert saved_successfully,
           "Application should save successfully within paper context, bypassing proof attachment validation. Errors: #{@application.errors.full_messages.join(', ')}"
    assert_empty @application.errors, 'Application should have no validation errors when saved in paper context'
  end

  test 'paper application context is properly cleaned up after exception' do
    assert_nil Thread.current[:paper_application_context], 'Context should be nil initially'

    begin
      setup_paper_application_context
      raise StandardError, 'Simulated error during processing'
    rescue StandardError
      # Error caught, context should be cleaned up by ensure block (if implemented correctly)
    ensure
      # Manually clean up in test if not using a wrapper module yet
      teardown_paper_application_context
    end

    assert_nil Thread.current[:paper_application_context], 'Context should be nil after exception and cleanup'

    # Verify normal validation runs again after context is cleared
    # Create a fresh application to avoid cached validation state
    fresh_application = FactoryBot.create(:application,
                                        user: @constituent,
                                        status: :in_progress,
                                        income_proof_status: :approved) # Invalid state - approved but no proof attached
    
    # Ensure no proofs are attached to this fresh application
    fresh_application.income_proof.detach if fresh_application.income_proof.attached?
    fresh_application.residency_proof.detach if fresh_application.residency_proof.attached?
    
    # Clear any validation errors from the initial save
    fresh_application.errors.clear
    
    assert_not fresh_application.valid?, 'Validation should be active again after context cleanup'
  end
end
