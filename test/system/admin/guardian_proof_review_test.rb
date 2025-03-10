require "application_system_test_case"

module AdminTests
  class GuardianProofReviewTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      @application = create(:application, :in_progress_with_pending_proofs, :submitted_by_guardian)

      # Sign in as admin
      visit sign_in_path
      fill_in "Email Address", with: @admin.email
      fill_in "Password", with: "password123"
      click_button "Sign In"
      assert_text "Dashboard" # Verify we're signed in
    end

    test "displays guardian alert in income proof review modal" do
      visit admin_application_path(@application)

      # Open the income proof review modal
      find("[data-action='click->modal#open'][data-modal-id='incomeProofReviewModal']").click

      # Verify the guardian alert is displayed
      within "#incomeProofReviewModal" do
        assert_text "Guardian Application"
        assert_text "This application was submitted by a parent on behalf of a minor"
        assert_text "Please verify this relationship when reviewing these proof documents"
      end
    end

    test "displays guardian alert in residency proof review modal" do
      visit admin_application_path(@application)

      # Open the residency proof review modal
      find("[data-action='click->modal#open'][data-modal-id='residencyProofReviewModal']").click

      # Verify the guardian alert is displayed
      within "#residencyProofReviewModal" do
        assert_text "Guardian Application"
        assert_text "This application was submitted by a parent on behalf of a minor"
        assert_text "Please verify this relationship when reviewing these proof documents"
      end
    end

    test "does not display guardian alert for non-guardian applications" do
      # Create a regular application (not from a guardian)
      regular_constituent = create(:constituent, is_guardian: false, guardian_relationship: nil)
      regular_application = create(:application, :in_progress_with_pending_proofs, user: regular_constituent)

      visit admin_application_path(regular_application)

      # Open the income proof review modal
      find("[data-action='click->modal#open'][data-modal-id='incomeProofReviewModal']").click

      # Verify the guardian alert is not displayed
      within "#incomeProofReviewModal" do
        assert_no_text "Guardian Application"
        assert_no_text "This application was submitted by a"
        assert_no_text "on behalf of a minor"
      end

      # Close the modal
      find("[data-action='click->modal#close']").click

      # Open the residency proof review modal
      find("[data-action='click->modal#open'][data-modal-id='residencyProofReviewModal']").click

      # Verify the guardian alert is not displayed
      within "#residencyProofReviewModal" do
        assert_no_text "Guardian Application"
        assert_no_text "This application was submitted by a"
        assert_no_text "on behalf of a minor"
      end
    end
  end
end
