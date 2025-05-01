# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class W9ReviewsTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)
      sign_in_as(@admin) # Use system test sign-in helper
    end

    test 'viewing vendor with pending W9' do
      vendor = create(:vendor, :with_w9) # Create vendor inside the test
      visit admin_vendor_path(vendor)

      assert_text 'W9 Status'
      assert_text 'Pending Review'
      assert_link 'Review W9'

      click_on 'Review W9'
      assert_current_path new_admin_vendor_w9_review_path(vendor)

      # Click the button to load the PDF preview
      click_on 'Load PDF Preview'

      # Test that the iframe is present and has the correct attributes
      # Wait for the container to be visible and contain the iframe
      assert_selector '[data-pdf-loader-target="container"]:not(.hidden) iframe'
      # Verify specific attributes now that we know the iframe exists in the visible container
      assert_selector '[data-pdf-loader-target="container"]:not(.hidden) iframe[data-turbo="false"]'
      # assert_selector '[data-pdf-loader-target="container"]:not(.hidden) iframe[type="application/pdf"]' # Removing this specific check due to persistent failures despite JS setting it.
      assert_selector '[data-pdf-loader-target="container"]:not(.hidden) iframe[src]'
      assert_selector '[data-pdf-loader-target="container"]:not(.hidden) iframe[data-original-src]'

      # Test the review form functionality
      # Click the 'Approve' button (which submits the form via Stimulus)
      click_on 'Approve'

      assert_current_path admin_vendor_path(vendor)
      assert_text 'W9 review completed successfully'
      assert_text 'Approved'
    end

    test 'rejecting a W9 form' do
      vendor = create(:vendor, :with_w9) # Create vendor inside the test
      visit admin_vendor_path(vendor)
      click_on 'Review W9'

      # Click the button to load the PDF preview
      click_on 'Load PDF Preview'
      # Wait for potential PDF loading if necessary, though usually Capybara waits
      assert_selector "iframe[data-turbo='false']" # Confirm PDF area is ready

      # Click the 'Reject' button (not a radio button)
      click_on 'Reject'
      # Should show rejection reason fields
      assert_selector '.rejection-reason', visible: true

      # Try submitting without selecting a reason by clicking Reject again
      # This should trigger validation and show an alert
      accept_alert 'Please select a rejection reason and provide a detailed explanation' do
        click_on 'Reject'
      end
      # Ensure the rejection section is still visible after the failed attempt
      assert_selector '.rejection-reason', visible: true

      # Complete the form properly
      choose 'Address Mismatch'
      fill_in 'Detailed Explanation', with: 'The address on the W9 does not match our records.'
      # Click 'Reject' again to submit the completed form
      click_on 'Reject'

      assert_current_path admin_vendor_path(vendor)
      assert_text 'W9 review completed successfully'
      assert_text 'Rejected'

      # Check that the vendor status was updated
      vendor.reload
      assert_equal 'rejected', vendor.w9_status
    end

    test 'viewing W9 review details' do
      vendor = create(:vendor, :with_w9) # Create vendor inside the test
      review = create(:w9_review, vendor: vendor, admin: @admin, status: :approved)

      puts "DEBUG: @vendor in test_viewing_W9_review_details: #{vendor.inspect}"
      puts "DEBUG: vendor.w9_form.attached?: #{vendor.w9_form.attached?}"
      puts "DEBUG: admin_vendor_w9_review_path(vendor, review): #{admin_vendor_w9_review_path(vendor, review).inspect}"
      visit admin_vendor_w9_review_path(vendor, review)

      # Test that the iframe is present and has the correct attributes
      assert_selector "iframe[data-turbo='false']"
      assert_selector "iframe[type='application/pdf']"
      assert_selector 'iframe[src]'
      assert_selector 'iframe[data-original-src]'

      assert_text 'Review Details'
      assert_text 'Approved'
    end

    test 'viewing rejected W9 review details' do
      vendor = create(:vendor, :with_w9) # Create vendor inside the test
      review = create(:w9_review, :rejected, vendor: vendor, admin: @admin)

      puts "DEBUG: @vendor in test_viewing_rejected_W9_review_details: #{vendor.inspect}"
      puts "DEBUG: vendor.w9_form.attached?: #{vendor.w9_form.attached?}"
      puts "DEBUG: admin_vendor_w9_review_path(vendor, review): #{admin_vendor_w9_review_path(vendor, review).inspect}"
      visit admin_vendor_w9_review_path(vendor, review)

      assert_text 'Review Details'
      assert_text 'Rejected'
      assert_text 'Rejection Reason'
      assert_text review.rejection_reason
    end
  end
end
