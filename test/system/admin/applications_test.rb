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
  end
end
