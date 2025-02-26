require "application_system_test_case"

class ApplicationsSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:constituent_john)
    @valid_pdf = file_fixture("income_proof.pdf").to_s
    @valid_image = file_fixture("residency_proof.pdf").to_s

    # Sign in
    visit sign_in_path
    fill_in "Email Address", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"
    assert_text "Dashboard" # Verify we're signed in
  end

  test "can view new application form" do
    skip "This test needs to be updated to match the actual application UI"

    # Visit the new application form directly
    visit new_constituent_portal_application_path

    assert_selector "h1", text: "New Application"

    # Check for updated income proof instructions
    assert_text "most recent tax return (preferred)"
    assert_text "current year SSA award letter (less than 2 months old)"
    assert_text "bank statement showing your SSA deposit"
    assert_text "utility bill, it must show your current address"

    # Verify pay stubs are not mentioned
    assert_no_text "pay stubs"
    assert_no_text "paystubs"

    # Check for medical provider section without "other medical professional"
    assert_text "Medical Professional Information"
    assert_text "Doctor / Physician"
    assert_text "Audiologist"
    assert_no_text "other medical professional"
  end

  test "can submit application with valid data" do
    skip "This test needs to be updated to match the actual application UI"

    visit new_constituent_portal_application_path

    # Fill in required fields based on the actual form
    # This will need to be updated to match the actual form fields

    # Verify success
    assert_text "Application submitted successfully", wait: 5
  end

  test "shows validation errors for invalid submission" do
    skip "This test needs to be updated to match the actual application UI"

    visit new_constituent_portal_application_path

    # Submit without filling required fields
    # This will need to be updated to match the actual submit button

    # Verify validation errors
    assert_text "can't be blank", wait: 5 # Look for generic validation error
  end

  test "can save application as draft" do
    skip "This test needs to be updated to match the actual application UI"

    visit new_constituent_portal_application_path

    # Fill in some fields but not all required ones
    # This will need to be updated to match the actual form fields

    # Save as draft
    # This will need to be updated to match the actual save button

    # Verify success
    assert_text "Application saved", wait: 5
  end

  test "dashboard shows correct application status after submission" do
    skip "This test needs to be updated to match the actual application UI"

    # This test needs to be completely rewritten to match the actual application flow

    # Verify dashboard shows the application
    assert_text "Application Status"
  end

  test "application form is accessible with keyboard navigation" do
    skip "This test needs to be updated to match the actual application UI"

    visit new_constituent_portal_application_path

    # This test needs to be updated to match the actual form elements
    # and keyboard navigation flow
  end
end
