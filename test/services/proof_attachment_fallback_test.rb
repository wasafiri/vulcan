# frozen_string_literal: true

require 'test_helper'

class ProofAttachmentFallbackTest < ActiveSupport::TestCase
  # Since both tests modify the database similarly, run them one at a time
  self.use_transactional_tests = true

  setup do
    @application = applications(:draft_application)
    @admin = users(:admin_david)
    # Clear out any existing audit records to ensure our tests are isolated
    ProofSubmissionAudit.delete_all
  end

  test 'record_failure handles missing submission_method gracefully' do
    # Generate a test-specific proof type to avoid conflicts
    proof_type = "income_#{Time.now.to_i}"

    # Deliberately passing nil as submission_method to test fallback
    error = StandardError.new('Test error')
    metadata = { ip_address: '127.0.0.1' }

    # This should not raise an error due to our fallback handling
    assert_nothing_raised do
      ProofAttachmentService.record_failure(
        @application,
        proof_type,
        error,
        @admin,
        nil, # Deliberately nil submission_method
        metadata
      )
    end

    # Verify audit record was created with fallback submission method
    audit = ProofSubmissionAudit.last
    assert_not_nil audit.submission_method
    assert_equal proof_type, audit.proof_type
    assert_equal false, audit.metadata['success']
  end

  test 'record_failure handles invalid submission_method gracefully' do
    # Generate a test-specific proof type to avoid conflicts
    proof_type = "residency_#{Time.now.to_i}"

    # Deliberately passing an invalid submission_method to test fallback
    error = StandardError.new('Test error')
    metadata = { ip_address: '127.0.0.1' }

    # This should not raise an error due to our fallback handling
    assert_nothing_raised do
      ProofAttachmentService.record_failure(
        @application,
        proof_type,
        error,
        @admin,
        :invalid_method, # Invalid submission method
        metadata
      )
    end

    # Verify audit record was created with fallback submission method
    audit = ProofSubmissionAudit.last
    assert_not_nil audit.submission_method
    assert_equal proof_type, audit.proof_type
    assert_equal false, audit.metadata['success']
  end
end
