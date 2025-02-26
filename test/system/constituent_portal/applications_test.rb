require "application_system_test_case"

class ApplicationsSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:constituent_john)
    @valid_pdf = file_fixture("valid.pdf")
    @valid_image = file_fixture("valid.jpg")

    # Create test image if it doesn't exist
    unless File.exist?(file_fixture_path.join("valid.jpg"))
      FileUtils.cp(file_fixture_path.join("valid.pdf"), file_fixture_path.join("valid.jpg"))
    end

    # Sign in
    visit sign_in_path
    fill_in "Email Address", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"
    assert_text "Dashboard" # Verify we're signed in
  end

  test "can view new application form" do
    visit constituent_portal_dashboard_path
    click_on "Start New Application"

    assert_selector "h1", text: "New Application"
    assert_selector "label", text: "Household Size"
    assert_selector "label", text: "Annual Income"
    assert_selector "label", text: "Income Verification"

    # Check for updated income proof instructions
    assert_text "We need proof of your household income. Please provide your most recent tax return (preferred)"
    assert_text "current year SSA award letter (less than 2 months old)"
    assert_text "recent bank statement showing your SSA deposit"
    assert_text "If providing a utility bill, it must show your current address"

    # Verify pay stubs are not mentioned
    assert_no_text "pay stubs"
    assert_no_text "paystubs"

    # Check for medical provider section without "other medical professional"
    within "section[aria-labelledby='medical-info-heading']" do
      assert_text "Medical Professional Information"
      assert_text "Doctor / Physician"
      assert_text "Audiologist"
      assert_no_text "other medical professional"
    end
  end

  test "can submit application with valid data" do
    visit new_constituent_portal_application_path

    # Fill in required fields
    check "I certify that I am a resident of Maryland"
    fill_in "Household Size", with: "3"
    fill_in "Annual Income", with: "50000"
    check "I certify that I have a disability that affects my ability to access telecommunications services"
    check "Hearing"

    # Fill in medical provider info
    within "section[aria-labelledby='medical-info-heading']" do
      fill_in "Name", with: "Dr. Smith"
      fill_in "Phone", with: "2025551234"
      fill_in "Email", with: "drsmith@example.com"
    end

    # Upload documents
    attach_file "Proof of Residency", @valid_image.path, make_visible: true
    attach_file "Income Verification", @valid_pdf.path, make_visible: true

    # Submit the application
    click_button "Submit Application"

    # Verify success
    assert_text "Application submitted successfully"
    assert_selector "h1", text: "Application #"

    # Verify uploaded documents are displayed
    assert_text "Income Proof"
    assert_text @valid_pdf.basename.to_s
    assert_text "Residency Proof"
    assert_text @valid_image.basename.to_s
  end

  test "shows validation errors for invalid submission" do
    visit new_constituent_portal_application_path

    # Submit without filling required fields
    click_button "Submit Application"

    # Verify validation errors
    assert_text "prohibited this application from being saved"
    assert_text "Maryland resident You must be a Maryland resident to apply"
    assert_text "Household size can't be blank"
    assert_text "Annual income can't be blank"
  end

  test "can save application as draft" do
    visit new_constituent_portal_application_path

    # Fill in some fields but not all required ones
    check "I certify that I am a resident of Maryland"
    fill_in "Household Size", with: "3"

    # Save as draft
    click_button "Save Application"

    # Verify success
    assert_text "Application saved as draft"
  end

  test "dashboard shows correct application status after submission" do
    # First create and submit an application
    visit new_constituent_portal_application_path

    # Fill in required fields
    check "I certify that I am a resident of Maryland"
    fill_in "Household Size", with: "3"
    fill_in "Annual Income", with: "50000"
    check "I certify that I have a disability that affects my ability to access telecommunications services"

    # Fill in medical provider info
    within "section[aria-labelledby='medical-info-heading']" do
      fill_in "Name", with: "Dr. Smith"
      fill_in "Phone", with: "2025551234"
      fill_in "Email", with: "drsmith@example.com"
    end

    # Upload documents
    attach_file "Proof of Residency", @valid_image.path, make_visible: true
    attach_file "Income Verification", @valid_pdf.path, make_visible: true

    # Submit the application
    click_button "Submit Application"

    # Now go to dashboard
    visit constituent_portal_dashboard_path

    # Verify dashboard shows the application
    assert_text "Application Status"
    assert_text "In Progress"
    assert_no_text "Start New Application"
    assert_text "View Application Details"
  end

  test "application form is accessible with keyboard navigation" do
    visit new_constituent_portal_application_path

    # Test skip link
    find("a", text: "Skip to main content").click
    assert_equal find("#main-content")[:id], page.evaluate_script("document.activeElement.id")

    # Test tab order - first few elements
    page.send_keys(:tab)
    assert_equal "maryland_resident", page.evaluate_script("document.activeElement.id")

    page.send_keys(:tab)
    assert_equal "application_household_size", page.evaluate_script("document.activeElement.id")

    page.send_keys(:tab)
    assert_equal "application_annual_income", page.evaluate_script("document.activeElement.id")
  end
end
