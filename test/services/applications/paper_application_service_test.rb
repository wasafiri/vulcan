require "test_helper"

module Applications
  class PaperApplicationServiceTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_david)
      @constituent_params = {
        first_name: "Test",
        last_name: "User",
        email: "test-#{Time.now.to_i}@example.com",
        phone: "2025551234",
        physical_address_1: "123 Test St",
        city: "Baltimore",
        state: "MD",
        zip_code: "21201",
        hearing_disability: "1",
        vision_disability: "0",
        speech_disability: "0",
        mobility_disability: "0",
        cognition_disability: "0"
      }
      
      @application_params = {
        household_size: "2",
        annual_income: "15000",
        maryland_resident: "1",
        self_certify_disability: "1",
        medical_provider_name: "Dr. Smith",
        medical_provider_phone: "2025559876",
        medical_provider_email: "drsmith@example.com"
      }
      
      # Use existing test files
      @pdf_file = fixture_file_upload(
        Rails.root.join("test", "fixtures", "files", "income_proof.pdf"),
        "application/pdf"
      )
      
      @invalid_file = fixture_file_upload(
        Rails.root.join("test", "fixtures", "files", "invalid.exe"),
        "application/octet-stream"
      )
      
      @large_file_mock = Minitest::Mock.new
      @large_file_mock.expect :content_type, "application/pdf"
      @large_file_mock.expect :byte_size, 10.megabytes
    end
    
    test "approved income proof must have an attachment" do
      service_params = {
        constituent: @constituent_params,
        application: @application_params,
        income_proof_action: "accept",
        income_proof: @pdf_file
      }
      
      service = PaperApplicationService.new(params: service_params, admin: @admin)
      assert service.create, "Failed to create paper application"
      
      # Verify the application was created with the income proof attached
      application = Constituent.find_by(email: @constituent_params[:email]).applications.last
      assert_not_nil application
      assert application.income_proof.attached?
      assert application.income_proof_status_approved?
    end
    
    test "application creation fails when blob creation fails" do
      service_params = {
        constituent: @constituent_params,
        application: @application_params,
        income_proof_action: "accept",
        income_proof: @pdf_file
      }
      
      service = PaperApplicationService.new(params: service_params, admin: @admin)
      
      # Mock the blob creation to raise an error
      ActiveStorage::Blob.stub :create_and_upload!, -> (*args) { raise ActiveStorage::IntegrityError.new("Test integrity error") } do
        assert_not service.create, "Paper application should fail when blob creation fails"
      end
    end
    
    test "application creation fails when S3 upload fails" do
      service_params = {
        constituent: @constituent_params,
        application: @application_params,
        income_proof_action: "accept",
        income_proof: @pdf_file
      }
      
      service = PaperApplicationService.new(params: service_params, admin: @admin)
      
      # Create a mock AWS error
      aws_error = Class.new(StandardError) do
        def code; "AccessDenied"; end
        def message; "Access Denied"; end
      end
      
      # Mock the blob creation to raise an AWS error
      aws_s3_error = Aws::S3::Errors::ServiceError.new(nil, aws_error.new)
      ActiveStorage::Blob.stub :create_and_upload!, -> (*args) { raise aws_s3_error } do
        assert_not service.create, "Paper application should fail when S3 upload fails"
      end
    end
    
    test "rejected proofs do not require attachment" do
      service_params = {
        constituent: @constituent_params,
        application: @application_params,
        income_proof_action: "reject",
        income_proof_rejection_reason: "other",
        income_proof_rejection_notes: "Test rejection"
      }
      
      service = PaperApplicationService.new(params: service_params, admin: @admin)
      assert service.create, "Failed to create paper application with rejected proof"
      
      # Verify the application was created with rejected income proof
      application = Constituent.find_by(email: @constituent_params[:email]).applications.last
      assert_not_nil application
      assert_not application.income_proof.attached?
      assert application.income_proof_status_rejected?
      
      # Verify proof review was created
      proof_review = application.proof_reviews.find_by(proof_type: "income")
      assert_not_nil proof_review
      assert_equal "rejected", proof_review.status
    end
    
    test "application rejects invalid file types" do
      service_params = {
        constituent: @constituent_params,
        application: @application_params,
        income_proof_action: "accept",
        income_proof: @invalid_file
      }
      
      service = PaperApplicationService.new(params: service_params, admin: @admin)
      assert_not service.create, "Paper application with invalid file type should be rejected"
    end
    
    test "application rejects files that exceed size limit" do
      # Mock an oversized file
      large_file = fixture_file_upload(
        Rails.root.join("test", "fixtures", "files", "income_proof.pdf"),
        "application/pdf"
      )
      
      ActiveStorage::Blob.stub_any_instance(:byte_size, 10.megabytes) do
        service_params = {
          constituent: @constituent_params,
          application: @application_params,
          income_proof_action: "accept",
          income_proof: large_file
        }
        
        service = PaperApplicationService.new(params: service_params, admin: @admin)
        assert_not service.create, "Paper application with oversized file should be rejected"
      end
    end
  end
end
