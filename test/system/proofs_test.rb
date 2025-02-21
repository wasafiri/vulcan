require "application_system_test_case"

class ProofsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @valid_income_proof = fixture_file_upload("test/fixtures/files/valid.pdf", "application/pdf")
    @valid_residency_proof = fixture_file_upload("test/fixtures/files/valid.pdf", "application/pdf")
  end

  test "complete application flow with proof submission" do
    # Start at sign in page and click sign up
    visit sign_in_path
    assert_text "Sign In" # Verify we're on sign in page

    within("p", text: "Don't have an account?") do
      click_on "Sign Up"
    end

    # Verify we're on the registration page
    assert_text "Create Account"
    assert_selector "form" # Verify form exists

    # Fill in registration form
    fill_in "First Name", with: "John"
    fill_in "Last Name", with: "Smith"
    fill_in "Email Address", with: "john.smith@example.com"
    fill_in "Password", with: "password123"
    fill_in "Confirm Password", with: "password123"
    fill_in "Phone Number", with: "202-555-1234"
    fill_in "Date of Birth", with: "1990-01-01"
    select "English", from: "Language Preference"
    click_button "Create Account"

    # Should redirect to home page
    assert_current_path root_path

    # Start application process
    click_on "Apply Now"

    # Fill in application form
    check "I certify that I am a resident of Maryland"
    fill_in "Household Size", with: "5"
    fill_in "Annual Income", with: "100000"
    check "I certify that I have a disability that affects my ability to access telecommunications services"
    check "Hearing"

    # Fill in medical provider information
    within("section", text: "Medical Professional Information") do
      fill_in "Name", with: "Dr. Feelgood"
      fill_in "Phone", with: "202-555-5555"
      fill_in "Fax (Optional)", with: "202-555-5556"
      fill_in "Email", with: "drfel@gmail.net"
    end

    # Attach proofs
    attach_file "Proof of Residency", @valid_residency_proof.path
    attach_file "Income Verification", @valid_income_proof.path

    # Submit application
    click_button "Submit Application"

    # Verify we're on the application show page
    assert_text "Application Details"

    # Verify application details
    assert_text "Application Type: Not specified"
    assert_text "Submission Method: Online"
    assert_text "Status: In Progress"
    assert_text "Household Size: 5"
    assert_text "Annual Income: $100,000.00"
    assert_text "Income Verification Status: Not Reviewed"
    assert_text "Income Verified At: Not verified"
    assert_text "Income Verified By: Not verified"
    assert_text "Income Details: None provided"
    assert_text "Residency Details: None provided"
    assert_text "Review Count: 0"

    # Verify medical provider information
    assert_text "Medical Provider Information"
    assert_text "Name: Dr. Feelgood"
    assert_text "Phone: 202-555-5555"
    assert_text "Email: drfel@gmail.net"

    # Verify proof sections exist
    assert_text "Income Proof"
    assert_text "Residency Proof"

    # Verify action buttons
    assert_link "Edit Application"
    assert_link "Back to Dashboard"
  end
end
