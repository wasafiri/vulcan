# frozen_string_literal: true

# test/system/admin/proof_reviews_test.rb
require 'application_system_test_case'

module Admin
  class ProofReviewsTest < ApplicationSystemTestCase
    include ActiveJob::TestHelper

    setup do
      @admin = create(:admin)
      @application = create(:application, :submitted_proofs_pending)

      # Create and attach test proofs
      fixture_dir = Rails.root.join('test/fixtures/files')
      FileUtils.mkdir_p(fixture_dir)

      # Create test files if they don't exist
      ['income_proof.pdf', 'residency_proof.pdf'].each do |filename|
        file_path = fixture_dir.join(filename)
        File.write(file_path, "test content for #{filename}") unless File.exist?(file_path)
      end

      # Attach proofs and save application
      @application.transaction do
        # Ensure proofs are attached and have proper content type
        @application.income_proof.attach(
          io: File.open(fixture_dir.join('income_proof.pdf')),
          filename: 'income_proof.pdf',
          content_type: 'application/pdf'
        )
        @application.residency_proof.attach(
          io: File.open(fixture_dir.join('residency_proof.pdf')),
          filename: 'residency_proof.pdf',
          content_type: 'application/pdf'
        )

        # Verify attachments were successful
        raise 'Failed to attach income proof' unless @application.income_proof.attached?
        raise 'Failed to attach residency proof' unless @application.residency_proof.attached?

        # Create notification and proof review
        NotificationService.create_and_deliver!(
          type: 'proof_submitted',
          recipient: @admin,
          actor: @application.user,
          notifiable: @application,
          metadata: { proof_types: %w[income residency] }
        )

        # Create a proof review to show in audit logs
        ProofReview.create!(
          application: @application,
          admin: @admin,
          proof_type: :income,
          status: :approved,
          reviewed_at: Time.current,
          submission_method: :web
        )

        @application.save!
      end
    end

    test 'admin reviews application proofs' do
      # Sign in as admin
      sign_in_as(@admin)
      assert_text 'Applications' # Admin applications index page

      # Visit applications page and filter
      visit admin_applications_path
      click_on 'Proofs Needing Review'
      assert_text 'Applications' # Wait for page to load

      # Find and click on our test application
      within('.applications-table') do
        within('tr', text: @application.user.full_name) do
          click_on 'View Application'
        end
      end

      # Verify application details page
      assert_text 'Application Details'
      assert_text 'In progress' # Status is shown as a badge

      # Review income proof
      within('#attachments-section') do
        within('.flex.items-center.justify-between', text: /Income Proof:/) do
          click_on 'Review Proof'
        end
      end
      assert_text 'Review Income Proof'

      # Wait for modal to appear and verify content
      within('#incomeProofReviewModal') do
        assert_text 'Review Income Proof'
        assert_button 'Approve'
        assert_button 'Reject'
      end

      # Approve income proof
      within('#incomeProofReviewModal') do
        click_button 'Approve'
      end

      # Wait for approval to complete and verify
      assert_text 'Income proof approved successfully'
      assert_text 'Income Proof: Approved'

      # Review residency proof
      within('#attachments-section') do
        within('.flex.items-center.justify-between', text: /Residency Proof:/) do
          click_on 'Review Proof'
        end
      end
      assert_text 'Review Residency Proof'

      # Wait for modal to appear and verify content
      within('#residencyProofReviewModal') do
        assert_text 'Review Residency Proof'
        assert_button 'Approve'
        assert_button 'Reject'
      end

      # Approve residency proof
      within('#residencyProofReviewModal') do
        click_button 'Approve'
      end

      # Wait for approval to complete and verify
      assert_text 'Residency proof approved successfully'
      assert_text 'Residency Proof: Approved'

      # Verify audit logs show the approvals and notifications
      within('#audit-logs tbody') do
        assert_text 'Admin approved Income proof'
        assert_text 'Admin approved Residency proof'
        assert_text 'Constituent notified: Income proof approved'
        assert_text 'Constituent notified: Residency proof approved'
      end

      # Both proofs are approved, we can now request medical certification
      accept_confirm "Do you want to send Downtown Medical the request to fill out Alex Smith's disability certification form?" do
        click_on 'Send Request'
      end
      assert_text 'Certification request'

      # Verify medical certification status updated
      assert_text 'Certification requested on'
      assert_text '(1 request sent)'
    end

    test 'admin receives notification for new proofs' do
      # Sign in as admin
      sign_in_as(@admin)
      assert_text 'Applications' # Admin applications index page

      # Visit applications page and view our test application
      visit admin_applications_path
      within('.applications-table') do
        within('tr', text: @application.user.full_name) do
          click_on 'View Application'
        end
      end

      # Verify we can see the proofs
      within('#attachments-section') do
        assert_text 'Income Proof: Not Reviewed'
        assert_text 'Residency Proof: Not Reviewed'
      end

      # Verify notification appears in audit logs
      within('#audit-logs tbody') do
        assert_text 'Admin Review'
        assert_text 'Notification Sent'
        assert_text 'Admin approved Income proof'
      end
    end
  end
end
