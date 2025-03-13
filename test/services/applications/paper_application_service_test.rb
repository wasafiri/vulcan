require 'test_helper'

module Applications
  class PaperApplicationServiceTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin)
      @params = {
        constituent: {
          first_name: "Test",
          last_name: "User",
          email: "test@example.com",
          phone: "123-456-7890",
          physical_address_1: "123 Main St",
          city: "Anytown",
          state: "MD",
          zip_code: "12345"
        },
        application: {
          household_size: 2,
          annual_income: 15000,
          maryland_resident: true,
          self_certify_disability: true,
          medical_provider_name: "Dr. Smith",
          medical_provider_phone: "555-123-4567",
          medical_provider_email: "doctor@example.com"
        },
        income_proof_action: "accept",
        residency_proof_action: "reject",
        residency_proof_rejection_reason: "expired",
        residency_proof_rejection_notes: "Your document is expired"
      }
    end

    test "creates application with accepted income proof and rejected residency proof" do
      # Use existing fixture file
      file = fixture_file_upload('files/test_document.pdf', 'application/pdf')
      @params[:income_proof] = file

      service = PaperApplicationService.new(
        params: @params,
        admin: @admin
      )

      assert service.create
      assert service.application.present?
      assert service.constituent.present?
      
      # Check application attributes
      assert_equal 2, service.application.household_size
      assert_equal 15000, service.application.annual_income
      assert_equal "paper", service.application.submission_method
      
      # Check proof statuses
      assert service.application.income_proof_status_approved?
      assert service.application.residency_proof_status_rejected?
      
      # Check proof file attachment
      assert service.application.income_proof.attached?
      refute service.application.residency_proof.attached?
      
      # Check proof review
      residency_reviews = service.application.proof_reviews.where(proof_type: "residency")
      assert_equal 1, residency_reviews.count
      review = residency_reviews.first
      assert_equal "rejected", review.status
      assert_equal "expired", review.rejection_reason
      assert_equal "Your document is expired", review.notes
      assert_equal "paper", review.submission_method
    end

    test "creates application with both proofs rejected" do
      @params[:income_proof_action] = "reject"
      @params[:income_proof_rejection_reason] = "missing_amount"
      @params[:income_proof_rejection_notes] = "Income amount not visible"
      
      # Include test file even though it will be rejected
      file = fixture_file_upload('files/test_document.pdf', 'application/pdf')
      @params[:income_proof] = file

      service = PaperApplicationService.new(
        params: @params,
        admin: @admin
      )

      assert service.create
      
      # Check proof statuses
      assert service.application.income_proof_status_rejected?
      assert service.application.residency_proof_status_rejected?
      
      # Check proof reviews
      assert_equal 2, service.application.proof_reviews.count
      
      income_review = service.application.proof_reviews.find_by(proof_type: "income")
      assert_equal "missing_amount", income_review.rejection_reason
      
      residency_review = service.application.proof_reviews.find_by(proof_type: "residency")
      assert_equal "expired", residency_review.rejection_reason
    end

    test "finds existing constituent by email" do
      existing = Constituent.create!(
        first_name: "Existing",
        last_name: "User",
        email: "test@example.com",
        password: "password123"
      )

      service = PaperApplicationService.new(
        params: @params,
        admin: @admin
      )

      assert service.create
      assert_equal existing.id, service.constituent.id
    end

    test "validates income threshold" do
      # Set income above threshold
      @params[:application][:annual_income] = 999999
      
      service = PaperApplicationService.new(
        params: @params,
        admin: @admin
      )

      refute service.create
      assert_includes service.errors, "Income exceeds the maximum threshold for the household size."
    end
  end
end
