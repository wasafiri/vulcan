require 'test_helper'

class ProofAttachmentServiceTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess
  
  setup do
    # Disconnect any lingering database connections and set up Active Storage properly
    disconnect_test_database_connections
    setup_active_storage_test
    
    @admin = users(:admin_david)
    @constituent = users(:constituent_john)
    
    @application = @constituent.applications.create!(
      household_size: 2,
      annual_income: 15000,
      maryland_resident: true,
      self_certify_disability: true,
      application_date: Time.current,
      status: :in_progress,
      medical_provider_name: "Dr. Smith",
      medical_provider_phone: "2025559876",
      medical_provider_email: "drsmith@example.com"
    )
    
    # Create a simple text file for testing instead of requiring PDF
    @test_file = Tempfile.new(['income_proof', '.txt'])
    @test_file.write("This is test income proof content")
    @test_file.rewind
    
    @test_file_upload = ActionDispatch::Http::UploadedFile.new(
      tempfile: @test_file,
      filename: "income_proof.txt",
      type: "text/plain"
    )
  end
  
  test "attach_proof successfully attaches a proof and updates status" do
    result = ProofAttachmentService.attach_proof(
      application: @application,
      proof_type: "income",
      blob_or_file: @test_file_upload,
      status: :approved,
      admin: @admin,
      metadata: { ip_address: "127.0.0.1" }
    )
    
    assert result[:success], "Expected attach_proof to succeed"
    assert_not_nil result[:duration_ms], "Expected duration to be tracked"
    assert @application.income_proof.attached?, "Expected income proof to be attached"
    assert @application.income_proof_status_approved?, "Expected income proof status to be approved"
    
    # Verify audit was created
    audit = ProofSubmissionAudit.last
    assert_equal @application, audit.application
    assert_equal @admin, audit.user
    assert_equal "income", audit.proof_type
    assert_equal "paper", audit.submission_method
    assert_equal true, audit.metadata["success"]
    assert_equal "approved", audit.metadata["status"]
  end
  
  test "attach_proof handles errors gracefully" do
    # Simulate an error by providing invalid status
    result = nil
    
    # Use a block to catch errors raised during blob creation
    ActiveStorage::Blob.stub :create_and_upload!, -> (*args) { raise StandardError.new("Test error") } do
      result = ProofAttachmentService.attach_proof(
        application: @application,
        proof_type: "income",
        blob_or_file: @test_file_upload,
        status: :approved,
        admin: @admin,
        metadata: { ip_address: "127.0.0.1" }
      )
    end
    
    assert_not result[:success], "Expected attach_proof to fail"
    assert_not_nil result[:error], "Expected error to be captured"
    assert_not_nil result[:duration_ms], "Expected duration to be tracked"
    
    # Check that proof was not attached
    assert_not @application.income_proof.attached?, "Expected income proof not to be attached after error"
    
    # Verify failure audit was created
    audit = ProofSubmissionAudit.last
    assert_equal @application, audit.application
    assert_equal @admin, audit.user
    assert_equal "income", audit.proof_type
    assert_equal "paper", audit.submission_method
    assert_equal false, audit.metadata["success"]
    assert_equal "Test error", audit.metadata["error_message"]
  end
  
  test "reject_proof_without_attachment sets rejected status without attachment" do
    result = ProofAttachmentService.reject_proof_without_attachment(
      application: @application,
      proof_type: "income",
      admin: @admin,
      reason: "invalid_document",
      notes: "Document does not meet requirements",
      metadata: { ip_address: "127.0.0.1" }
    )
    
    assert result[:success], "Expected reject_proof_without_attachment to succeed"
    assert_not_nil result[:duration_ms], "Expected duration to be tracked"
    assert @application.income_proof_status_rejected?, "Expected income proof status to be rejected"
    assert_not @application.income_proof.attached?, "Expected no attachment for rejected proof"
    
    # Verify proof review was created
    proof_review = @application.proof_reviews.last
    assert_equal "income", proof_review.proof_type
    assert_equal "rejected", proof_review.status
    assert_equal "invalid_document", proof_review.rejection_reason
    
    # Verify audit was created
    audit = ProofSubmissionAudit.last
    assert_equal @application, audit.application
    assert_equal @admin, audit.user
    assert_equal "income", audit.proof_type
    assert_equal "paper", audit.submission_method
    assert_equal true, audit.metadata["success"]
    assert_equal false, audit.metadata["has_attachment"]
  end
  
  test "metrics recording handles exceptions gracefully" do
    # Mock the record_metrics method to raise an exception
    ProofAttachmentService.stub :record_metrics, -> (*args) { raise RuntimeError.new("Metrics error") } do
      # The overall operation should still succeed
      result = ProofAttachmentService.attach_proof(
        application: @application,
        proof_type: "income",
        blob_or_file: @test_file_upload,
        status: :approved,
        admin: @admin,
        metadata: { ip_address: "127.0.0.1" }
      )
      
      assert result[:success], "Operation should succeed even if metrics recording fails"
      assert @application.income_proof.attached?, "Proof should be attached"
    end
  end
end
