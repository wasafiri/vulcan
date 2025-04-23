# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ApplicationsTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)
      @application = create(:application, :in_progress_with_pending_proofs, skip_proofs: true)

      # Attach the proofs manually to ensure complete control over the attachments
      unless @application.income_proof.attached?
        @application.income_proof.attach(
          io: File.open(Rails.root.join('test/fixtures/files/income_proof.pdf')),
          filename: 'income_proof.pdf',
          content_type: 'application/pdf'
        )
      end

      unless @application.residency_proof.attached?
        @application.residency_proof.attach(
          io: File.open(Rails.root.join('test/fixtures/files/residency_proof.pdf')),
          filename: 'residency_proof.pdf',
          content_type: 'application/pdf'
        )
      end

      unless @application.medical_certification.attached?
        @application.medical_certification.attach(
          io: File.open(Rails.root.join('test/fixtures/files/medical_certification_valid.pdf')),
          filename: 'medical_certification_valid.pdf',
          content_type: 'application/pdf'
        )
      end

      # Set the medical certification status to 'received'
      @application.update!(medical_certification_status: :received)

      # Sign in as admin - using system test authentication
      system_test_sign_in(@admin)
    end

    test 'admin can view application details successfully with factory-created records' do
      visit admin_application_path(@application)

      # Verify the page loaded with our factory-created application
      assert_text "Application ##{@application.id} Details"
      assert_text @application.user.full_name

      # Verify sections exist
      assert_selector 'section', text: /Applicant Information/
      assert_selector 'section', text: /Application Details/
      assert_selector 'section', text: /Attachments/

      # Verify income and residency proof sections exist and show the correct status
      within '#attachments-section' do
        assert_text 'Income Proof'
        assert_text 'Not Reviewed'

        assert_text 'Residency Proof'
        assert_text 'Not Reviewed'
      end
    end

    test 'admin can approve medical certification directly via service' do
      # This test demonstrates that our factory-created application works with service objects
      assert_equal 'received', @application.medical_certification_status

      # Directly use the service object that the controller would use
      result = MedicalCertificationAttachmentService.update_certification_status(
        application: @application,
        status: :approved,
        admin: @admin
      )

      assert result[:success], 'Medical certification approval failed'

      # Verify the application record was updated
      @application.reload
      assert_equal 'approved', @application.medical_certification_status

      # Now visit the page to verify it shows correctly
      visit admin_application_path(@application)
      assert_text 'Medical Certification'
      assert_text 'Approved'
    end

    test 'factory-created application can have proofs approved and trigger certification request' do
      # Set up the application in the right state
      @application.update!(
        medical_certification_status: :not_requested,
        income_proof_status: :not_reviewed,
        residency_proof_status: :not_reviewed
      )

      # Directly approve proofs using services
      proof_reviewer = Applications::ProofReviewer.new(@application, @admin)

      income_result = proof_reviewer.review(
        proof_type: 'income',
        status: 'approved'
      )

      residency_result = proof_reviewer.review(
        proof_type: 'residency',
        status: 'approved'
      )

      # The ProofReviewer returns true for success, not a hash
      assert income_result, 'Income proof approval failed'
      assert residency_result, 'Residency proof approval failed'

      # Verify application state - this should now trigger the certification request
      @application.reload

      # Verify proof statuses were updated correctly
      assert_equal 'approved', @application.income_proof_status, 'Income proof status was not approved'
      assert_equal 'approved', @application.residency_proof_status, 'Residency proof status was not approved'

      # Verify the certification status was correctly updated to requested
      assert_equal 'requested', @application.medical_certification_status,
                   "Medical certification wasn't automatically requested after approving both proofs"

      # Success! We've confirmed the model behavior works with factory-created records
    end
  end
end
