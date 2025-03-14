require "test_helper"

class PaperApplicationModeSwitchingTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_david)
    sign_in @admin
    
    # Create sample proofs for testing
    @income_proof = fixture_file_upload("test/fixtures/files/sample.pdf", "application/pdf")
    @residency_proof = fixture_file_upload("test/fixtures/files/sample.pdf", "application/pdf")
  end
  
  test "paper application service properly handles mode switching between accept and reject" do
    # Create a test constituent to avoid validation issues
    @constituent = Constituent.create!(
      first_name: "Test",
      last_name: "User",
      email: "test.#{Time.now.to_i}@example.com",
      password: "password",
      verified: true,
      phone: "555-123-4567",
      physical_address_1: "123 Main St",
      city: "Baltimore",
      state: "MD",
      zip_code: "21201"
    )
    
    # Step 1: First create application with income proof attached but residency proof rejected
    income_blob = create_direct_upload_blob(@income_proof)
    
    post admin_paper_applications_path, params: {
      constituent: { id: @constituent.id },
      application: {
        household_size: 2,
        annual_income: 20000,
        maryland_resident: true,
        self_certify_disability: true,
        medical_provider_name: "Dr. Smith",
        medical_provider_phone: "555-123-4567",
        medical_provider_email: "dr.smith@example.com"
      },
      income_proof_action: "accept",
      income_proof_signed_id: income_blob.signed_id,
      residency_proof_action: "reject",
      residency_proof_rejection_reason: "missing_name",
      residency_proof_rejection_notes: "Name is missing on document"
    }
    
    assert_response :redirect
    application = Application.last
    assert_redirected_to admin_application_path(application)
    
    # Verify income proof is attached
    assert application.income_proof.attached?
    assert_equal "approved", application.income_proof_status
    
    # Verify residency proof is rejected but not attached
    assert_not application.residency_proof.attached?
    assert_equal "rejected", application.residency_proof_status
    
    # Step 2: Switch the modes - reject income and accept residency
    residency_blob = create_direct_upload_blob(@residency_proof)
    
    patch admin_paper_application_path(application), params: {
      income_proof_action: "reject",
      income_proof_rejection_reason: "expired",
      income_proof_rejection_notes: "Documentation is expired",
      residency_proof_action: "accept",
      residency_proof_signed_id: residency_blob.signed_id
    }
    
    assert_response :redirect
    application.reload
    
    # Verify income proof is now rejected and attachment is purged
    assert_not application.income_proof.attached?
    assert_equal "rejected", application.income_proof_status
    
    # Verify residency proof is now attached and approved
    assert application.residency_proof.attached?
    assert_equal "approved", application.residency_proof_status
    
    # Verify we have the correct proof reviews
    income_review = application.proof_reviews.find_by(proof_type: :income, status: :rejected)
    assert_equal "expired", income_review.rejection_reason
    
    residency_review = application.proof_reviews.find_by(proof_type: :residency, status: :rejected)
    assert_equal "missing_name", residency_review.rejection_reason
  end
  
  test "paper application service properly handles invalid signed_ids" do
    # This test verifies the service doesn't crash when given invalid signed_ids
    
    # Create a test constituent to avoid validation issues
    @constituent = Constituent.create!(
      first_name: "Test",
      last_name: "User",
      email: "test.invalid.#{Time.now.to_i}@example.com",
      password: "password",
      verified: true,
      phone: "555-123-4567",
      physical_address_1: "123 Main St",
      city: "Baltimore",
      state: "MD",
      zip_code: "21201"
    )
    
    # Attempt to create application with invalid signed_id
    post admin_paper_applications_path, params: {
      constituent: { id: @constituent.id },
      application: {
        household_size: 2,
        annual_income: 20000,
        maryland_resident: true,
        self_certify_disability: true,
        medical_provider_name: "Dr. Smith",
        medical_provider_phone: "555-123-4567",
        medical_provider_email: "dr.smith@example.com"
      },
      income_proof_action: "accept",
      income_proof_signed_id: "invalid-signed-id-that-doesnt-exist",
      residency_proof_action: "reject",
      residency_proof_rejection_reason: "missing_name"
    }
    
    # Should fail gracefully with error message
    assert_response :unprocessable_entity
    assert_match /Error processing proof:/i, flash[:alert]
  end
  
  private
  
  def create_direct_upload_blob(file)
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: file.original_filename,
      byte_size: file.size,
      checksum: OpenSSL::Digest::MD5.file(file.path).base64digest,
      content_type: file.content_type
    )
    
    # Simulate the direct upload by directly attaching content to the blob
    File.open(file.path) do |io|
      blob.upload(io)
    end
    
    blob
  end
end
