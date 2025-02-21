require "application_system_test_case"

class ProofUploadsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @application = applications(:one)
    @user = users(:constituent)
    @valid_pdf = file_fixture("valid.pdf")
    sign_in @user
  end

  test "shows upload form with progress bar" do
    visit new_constituent_application_proof_path(@application, proof_type: "income")

    assert_selector "h1", text: "Resubmit Income Proof"
    assert_selector "[data-upload-target='progress']"
    assert_selector "[data-upload-target='submit']"
  end

  test "uploads file with progress tracking" do
    visit new_constituent_application_proof_path(@application, proof_type: "income")

    # Attach file
    attach_file "income_proof", @valid_pdf, make_visible: true

    # Progress bar should appear
    assert_selector "[data-upload-target='progress']", visible: true

    # Submit form
    click_button "Submit"

    # Wait for upload to complete
    assert_selector ".flash", text: "Proof submitted successfully"

    # Verify upload completed
    @application.reload
    assert @application.income_proof.attached?
  end

  test "handles upload errors gracefully" do
    visit new_constituent_application_proof_path(@application, proof_type: "income")

    # Attach invalid file
    attach_file "income_proof", file_fixture("invalid.exe"), make_visible: true
    click_button "Submit"

    # Should show error message
    assert_text "must be a PDF or an image file"
    assert_selector ".flash.alert"
  end

  test "enforces rate limits in UI" do
    # Set up rate limit policy
    Policy.set("proof_submission_rate_limit_web", 1)
    Policy.set("proof_submission_rate_period", 1)

    # First upload should succeed
    visit new_constituent_application_proof_path(@application, proof_type: "income")
    attach_file "income_proof", @valid_pdf, make_visible: true
    click_button "Submit"
    assert_selector ".flash", text: "Proof submitted successfully"

    # Second upload should show rate limit error
    visit new_constituent_application_proof_path(@application, proof_type: "income")
    attach_file "income_proof", @valid_pdf, make_visible: true
    click_button "Submit"
    assert_selector ".flash.alert", text: "Please wait before submitting another proof"
  end

  test "shows file size limit in UI" do
    visit new_constituent_application_proof_path(@application, proof_type: "income")
    assert_text "Maximum size allowed is 5MB"
  end

  test "allows canceling upload" do
    visit new_constituent_application_proof_path(@application, proof_type: "income")

    # Attach file
    attach_file "income_proof", @valid_pdf, make_visible: true

    # Cancel button should appear during upload
    assert_selector "[data-upload-target='cancel']", visible: true

    # Click cancel
    click_button "Cancel Upload"

    # Progress bar should disappear
    assert_no_selector "[data-upload-target='progress']", visible: true
  end

  test "updates UI after successful upload" do
    visit new_constituent_application_proof_path(@application, proof_type: "income")

    # Attach and submit file
    attach_file "income_proof", @valid_pdf, make_visible: true
    click_button "Submit"

    # Should redirect to application page
    assert_current_path constituent_application_path(@application)
    assert_selector ".flash", text: "Proof submitted successfully"

    # Should show updated proof status
    assert_text "Income Proof Status: Not Reviewed"
  end

  test "maintains accessibility during upload" do
    visit new_constituent_application_proof_path(@application, proof_type: "income")

    # Form should be accessible
    assert_selector "label[for='income_proof']"
    assert_selector "[aria-label='Upload progress']"
    assert_selector "button[type='submit']"

    # Attach file
    attach_file "income_proof", @valid_pdf, make_visible: true

    # Progress information should be announced
    assert_selector "[role='progressbar']"
    assert_selector "[aria-live='polite']"
  end

  private

  def sign_in(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_button "Sign in"
  end
end
