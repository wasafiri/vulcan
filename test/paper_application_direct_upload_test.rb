require "test_helper"

class PaperApplicationDirectUploadTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @admin = users(:admin)
    sign_in @admin
  end

  test "direct upload for paper applications should work with signed_ids" do
    # Set up sample proof files
    income_proof = fixture_file_upload("test/fixtures/files/sample_income.pdf", "application/pdf")
    residency_proof = fixture_file_upload("test/fixtures/files/sample_residency.pdf", "application/pdf")
    
    # Create blobs using direct upload
    income_blob = create_direct_upload_blob(income_proof)
    residency_blob = create_direct_upload_blob(residency_proof)
    
    # Verify blobs were created
    assert_not_nil income_blob.signed_id
    assert_not_nil residency_blob.signed_id
    
    # Submit paper application with signed_ids
    assert_difference('Application.count') do
      post admin_paper_applications_path, params: {
        constituent: {
          first_name: "Test",
          last_name: "User",
          email: "test@example.com",
          phone: "555-555-5555",
          physical_address_1: "123 Main St",
          city: "Anytown",
          state: "MD",
          zip_code: "12345"
        },
        application: {
          household_size: 2,
          annual_income: 20000,
          maryland_resident: true,
          self_certify_disability: true,
          medical_provider_name: "Dr. Smith",
          medical_provider_phone: "555-123-4567",
          medical_provider_email: "smith@example.com"
        },
        income_proof_action: "accept",
        income_proof: income_blob.signed_id,
        residency_proof_action: "accept",
        residency_proof: residency_blob.signed_id
      }
    end
    
    # Check for successful redirects
    assert_redirected_to admin_application_path(Application.last)
    
    # Verify attachment was successful
    application = Application.last
    assert application.income_proof.attached?
    assert application.residency_proof.attached?
    
    # Verify statuses were set correctly
    assert_equal "approved", application.income_proof_status
    assert_equal "approved", application.residency_proof_status
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
  
  def sign_in(user)
    post "/sign_in", params: { email: user.email, password: "password" }
  end
end
