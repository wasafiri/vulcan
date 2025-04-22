# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ApplicationsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      @application = applications(:submitted_application)

      # Ensure all necessary attachments are present
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

      # Sign in as admin
      sign_in(@admin)
    end

    test 'admin can review medical certification from attachments section' do
      visit admin_application_path(@application)

      # Find and click the Review Certification button in the attachments section
      within '#attachments-section' do
        assert_text 'Medical Certification'
        click_on 'Review Certification'
      end

      # Verify the modal is displayed
      assert_selector '#medicalCertificationReviewModal', visible: true

      # Verify the certification preview is displayed
      within '#medicalCertificationReviewModal' do
        assert_selector 'iframe[data-original-src]', visible: true
        # Check that the iframe has a src attribute (which means it's loaded)
        assert page.has_css?('iframe[src]')

        # Approve the certification
        click_on 'Approve'
      end

      # Verify the certification status is updated
      assert_text 'Medical Certification: Accepted'

      # Verify the application record was updated
      @application.reload
      assert_equal 'accepted', @application.medical_certification_status
    end

    test 'admin can review medical certification from certification status section' do
      visit admin_application_path(@application)

      # Find and click the Review Certification button in the certification status section
      within "section[aria-labelledby='certification-status-title']" do
        assert_text 'Medical Certification Status'
        click_on 'Review Certification'
      end

      # Verify the modal is displayed
      assert_selector '#medicalCertificationReviewModal', visible: true

      # Verify the certification preview is displayed
      within '#medicalCertificationReviewModal' do
        assert_selector 'iframe[data-original-src]', visible: true
        # Check that the iframe has a src attribute (which means it's loaded)
        assert page.has_css?('iframe[src]')

        # Reject the certification
        click_on 'Reject'
      end

      # Verify the certification status is updated
      assert_text 'Medical Certification: Rejected'

      # Verify the application record was updated
      @application.reload
      assert_equal 'rejected', @application.medical_certification_status
    end

    test 'audit log shows medical certification requested event after proofs approved' do
      # Override status for this specific test, ensuring proofs are pending review
      @application.update!(medical_certification_status: :not_requested,
                           income_proof_status: :pending,
                           residency_proof_status: :pending)

      # Ensure proofs are attached (redundant if setup guarantees it, but safe)
      unless @application.income_proof.attached?
        @application.income_proof.attach(io: File.open(Rails.root.join('test/fixtures/files/income_proof.pdf')),
                                         filename: 'income_proof.pdf', content_type: 'application/pdf')
      end
      unless @application.residency_proof.attached?
        @application.residency_proof.attach(io: File.open(Rails.root.join('test/fixtures/files/residency_proof.pdf')),
                                            filename: 'residency_proof.pdf', content_type: 'application/pdf')
      end

      visit admin_application_path(@application)

      # Approve Income Proof
      # Assuming a structure like: <div class="proof-section ..."> ... <h3>Income Proof</h3> ... <a ...>Review Proof</a> ... </div>
      # And a modal with id #incomeProofReviewModal
      within '#attachments-section .proof-section', text: /Income Proof/ do
        click_on 'Review Proof'
      end
      within '#incomeProofReviewModal' do # Adjust modal ID if needed based on actual implementation
        click_on 'Approve'
      end
      # Wait for potential AJAX updates and check status text within the specific proof section
      within '#attachments-section .proof-section', text: /Income Proof/ do
        assert_text 'Status: Approved', wait: 5 # Adjust text if needed (e.g., "Approved")
      end

      # Approve Residency Proof
      # Assuming a structure like: <div class="proof-section ..."> ... <h3>Residency Proof</h3> ... <a ...>Review Proof</a> ... </div>
      # And a modal with id #residencyProofReviewModal
      within '#attachments-section .proof-section', text: /Residency Proof/ do
        click_on 'Review Proof'
      end
      within '#residencyProofReviewModal' do # Adjust modal ID if needed based on actual implementation
        click_on 'Approve'
      end
      # Wait for potential AJAX updates and check status text within the specific proof section
      within '#attachments-section .proof-section', text: /Residency Proof/ do
        assert_text 'Status: Approved', wait: 5 # Adjust text if needed (e.g., "Approved")
      end

      # Verify Audit Log Entry
      # Refresh the page to ensure the audit log reflects the latest events triggered by callbacks
      visit admin_application_path(@application)
      within '#audit-logs' do
        assert_text 'Medical certification requested (triggered by: All Proofs Approved)'
      end

      # Verify application state
      @application.reload
      assert_equal 'requested', @application.medical_certification_status
      assert_equal 'approved', @application.income_proof_status
      assert_equal 'approved', @application.residency_proof_status
    end
  end
end
