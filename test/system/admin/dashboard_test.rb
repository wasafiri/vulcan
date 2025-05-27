# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class DashboardTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)

      # Create some applications with different statuses
      @draft_app = create(:application, :draft)
      @in_progress_app = create(:application, :in_progress)
      @approved_app = create(:application, :approved)

      # Create applications with proofs needing review
      @app_with_pending_proof = create(:application, :in_progress_with_pending_proofs)

      # Create application with medical certification received
      @app_with_medical_cert = create(:application, :in_progress)
      @app_with_medical_cert.update!(medical_certification_status: :received)

      # Skip training request for now since the columns don't exist in the database
      # @app_with_training = create(:application, :in_progress)
      # @app_with_training.user.update!(training_requested: true, training_completed: false)

      # Sign in as admin
      sign_in(@admin)
    end

    test 'dashboard displays correct layout with charts below applications' do
      visit admin_applications_path

      # Verify page title
      assert_selector 'h1', text: 'Admin Dashboard'

      # Verify status cards section
      assert_selector "section[aria-labelledby='status-cards-heading']"
      assert_selector 'h3#in-progress-heading', text: 'In Progress Applications'
      assert_selector 'h3#approved-heading', text: 'Approved'

      # Verify common tasks section
      assert_selector "section[aria-labelledby='common-tasks-heading']"
      assert_selector 'h2#common-tasks-heading', text: 'Common Tasks'

      # Verify applications section
      assert_selector "section[aria-labelledby='applications-heading']"

      # Verify charts section appears after applications section
      # Instead of comparing DOM paths, check the order of elements on the page
      assert_selector "section[aria-labelledby='applications-heading'] ~ section[aria-labelledby='charts-heading']"

      # Verify chart headings
      assert_selector 'h3#pipeline-heading', text: 'Application Pipeline'
      assert_selector 'h3#status-breakdown-heading', text: 'Status Breakdown'
    end

    test 'common tasks section shows correct links with counts' do
      visit admin_applications_path

      within "section[aria-labelledby='common-tasks-heading']" do
        # Check for proofs needing review link
        assert_selector 'a', text: /Proofs Needing Review \(\d+\)/

        # Check for medical certs to review link
        assert_selector 'a', text: /Medical Certs to Review \(\d+\)/

        # Check for training requests link
        assert_selector 'a', text: /Training Requests \(\d+\)/
      end
    end

    test 'clicking on common tasks links filters applications correctly' do
      visit admin_applications_path

      # Click on proofs needing review link
      click_on 'Proofs Needing Review'

      # Verify we're on the filtered page
      assert_current_path admin_applications_path(filter: 'proofs_needing_review')

      # Verify the link is highlighted
      within "section[aria-labelledby='common-tasks-heading']" do
        assert_selector 'a.bg-gray-50', text: /Proofs Needing Review/
      end

      # Go back to main page
      visit admin_applications_path

      # Click on medical certs to review link
      click_on 'Medical Certs to Review'

      # Verify we're on the filtered page
      assert_current_path admin_applications_path(filter: 'medical_certs_to_review')

      # Verify the link is highlighted
      within "section[aria-labelledby='common-tasks-heading']" do
        assert_selector 'a.bg-gray-50', text: /Medical Certs to Review/
      end

      # Go back to main page
      visit admin_applications_path

      # Click on training requests link
      click_on 'Training Requests'

      # Verify we're on the filtered page
      assert_current_path admin_applications_path(filter: 'training_requests')

      # Verify the link is highlighted
      within "section[aria-labelledby='common-tasks-heading']" do
        assert_selector 'a.bg-gray-50', text: /Training Requests/
      end
    end

    test 'view reports button links to reports page' do
      visit admin_applications_path

      # Click on the View Reports button
      click_on 'View Reports'

      # Verify we're on the reports page
      assert_current_path admin_reports_path

      # Verify the reports page title
      assert_selector 'h1', text: 'System Reports'
    end

    test 'admin action buttons are present and functional' do
      visit admin_applications_path

      # Verify all four admin action buttons are present
      assert_selector 'a', text: 'Edit Policies'
      assert_selector 'a', text: 'Manage Products'
      assert_selector 'a', text: 'Upload Paper Application'
      assert_selector 'a', text: 'View Reports'

      # Test Edit Policies button
      click_on 'Edit Policies'
      assert_current_path admin_policies_path
      visit admin_applications_path

      # Test Manage Products button
      click_on 'Manage Products'
      assert_current_path admin_products_path
      visit admin_applications_path

      # Test Upload Paper Application button
      click_on 'Upload Paper Application'
      assert_current_path new_admin_paper_application_path
      visit admin_applications_path

      # Test View Reports button (already tested in previous test, but included for completeness)
      click_on 'View Reports'
      assert_current_path admin_reports_path
    end

    test 'admin action buttons have appropriate accessibility attributes' do
      visit admin_applications_path

      # Check for proper aria labels on admin action buttons
      assert_selector "a[aria-label='Edit system policies and settings']"
      assert_selector "a[aria-label='Manage products catalog']"
      assert_selector "a[aria-label='Upload a paper application']"
      assert_selector "a[aria-label='View detailed system reports']"

      # Verify buttons have adequate touch target size (min-h-[44px])
      assert_selector 'a.min-h-\\[44px\\]', count: 4
    end
  end
end
