require "application_system_test_case"

class Admin::W9ReviewsTest < ApplicationSystemTestCase
  setup do
    @admin = create(:admin)
    @vendor = create(:vendor, :with_w9)
    sign_in(@admin)
  end

  test "viewing vendor with pending W9" do
    visit admin_vendor_path(@vendor)

    assert_text "W9 Status"
    assert_text "Pending Review"
    assert_link "Review W9"

    click_on "Review W9"
    assert_current_path new_admin_vendor_w9_review_path(@vendor)

    # Test that the iframe is present and has the correct attributes
    assert_selector "iframe[data-turbo='false']"
    assert_selector "iframe[type='application/pdf']"
    assert_selector "iframe[src]"
    assert_selector "iframe[data-original-src]"

    # Test the review form functionality
    choose "Approve"
    click_on "Submit Review"

    assert_current_path admin_vendor_path(@vendor)
    assert_text "W9 review completed successfully"
    assert_text "Approved"
  end

  test "rejecting a W9 form" do
    visit admin_vendor_path(@vendor)
    click_on "Review W9"

    choose "Reject"
    # Should show rejection reason fields
    assert_selector ".rejection-reason", visible: true

    # Try submitting without selecting a reason
    click_on "Submit Review"
    assert_text "Please select a rejection reason and provide a detailed explanation"

    # Complete the form properly
    choose "Address Mismatch"
    fill_in "Detailed Explanation", with: "The address on the W9 does not match our records."
    click_on "Submit Review"

    assert_current_path admin_vendor_path(@vendor)
    assert_text "W9 review completed successfully"
    assert_text "Rejected"

    # Check that the vendor status was updated
    @vendor.reload
    assert_equal "rejected", @vendor.w9_status
  end

  test "viewing W9 review details" do
    review = create(:w9_review, vendor: @vendor, admin: @admin, status: :approved)

    visit admin_vendor_w9_review_path(@vendor, review)

    # Test that the iframe is present and has the correct attributes
    assert_selector "iframe[data-turbo='false']"
    assert_selector "iframe[type='application/pdf']"
    assert_selector "iframe[src]"
    assert_selector "iframe[data-original-src]"

    assert_text "Review Details"
    assert_text "Approved"
  end

  test "viewing rejected W9 review details" do
    review = create(:w9_review, :rejected, vendor: @vendor, admin: @admin)

    visit admin_vendor_w9_review_path(@vendor, review)

    assert_text "Review Details"
    assert_text "Rejected"
    assert_text "Rejection Reason"
    assert_text review.rejection_reason
  end
end
