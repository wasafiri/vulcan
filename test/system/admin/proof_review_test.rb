require "application_system_test_case"

class Admin::ProofReviewTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin_david)
    @application = applications(:submitted_application)

    # Store original environment variables
    @original_mailer_host = ENV["MAILER_HOST"]

    # Ensure all necessary attachments are present
    unless @application.income_proof.attached?
      @application.income_proof.attach(
        io: File.open(Rails.root.join("test/fixtures/files/income_proof.pdf")),
        filename: "income_proof.pdf",
        content_type: "application/pdf"
      )
    end

    unless @application.residency_proof.attached?
      @application.residency_proof.attach(
        io: File.open(Rails.root.join("test/fixtures/files/residency_proof.pdf")),
        filename: "residency_proof.pdf",
        content_type: "application/pdf"
      )
    end

    # Set the proof statuses to 'not_reviewed'
    @application.update!(
      income_proof_status: :not_reviewed,
      residency_proof_status: :not_reviewed
    )

    # Set the MAILER_HOST environment variable for the test
    ENV["MAILER_HOST"] = "example.com"

    # Sign in as admin
    sign_in(@admin)
  end

  teardown do
    # Restore original environment variables
    ENV["MAILER_HOST"] = @original_mailer_host
  end

  test "admin can review income proof with preview" do
    visit admin_application_path(@application)

    # Find and click the Review Proof button for income proof
    within "#attachments-section" do
      # Find the first div (which is the Income Proof section)
      all(".flex.items-center.justify-between")[0].find("button", text: "Review Proof").click
    end

    # Verify the modal is displayed
    assert_selector "#incomeProofReviewModal", visible: true

    # Verify the proof preview is displayed
    within "#incomeProofReviewModal" do
      assert_selector "iframe[data-original-src]", visible: true
      # Check that the iframe has a src attribute (which means it's loaded)
      assert page.has_css?("iframe[src]")

      # Approve the proof
      click_on "Approve"
    end

    # Verify the flash message
    assert_text "Income proof approved successfully."

    # Verify the application record was updated
    @application.reload
    assert_equal "approved", @application.income_proof_status
  end

  test "admin can review residency proof with preview" do
    visit admin_application_path(@application)

    # Find and click the Review Proof button for residency proof
    within "#attachments-section" do
      # Find the second div (which is the Residency Proof section)
      all(".flex.items-center.justify-between")[1].find("button", text: "Review Proof").click
    end

    # Verify the modal is displayed
    assert_selector "#residencyProofReviewModal", visible: true

    # Verify the proof preview is displayed
    within "#residencyProofReviewModal" do
      assert_selector "iframe[data-original-src]", visible: true
      # Check that the iframe has a src attribute (which means it's loaded)
      assert page.has_css?("iframe[src]")

      # Approve the proof
      click_on "Approve"
    end

    # Verify the proof status is updated in the UI
    within "#attachments-section" do
      assert_text "Residency Proof: Approved"
    end

    # Verify the application record was updated
    @application.reload
    assert_equal "approved", @application.residency_proof_status
  end
end
