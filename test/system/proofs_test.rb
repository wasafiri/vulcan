# frozen_string_literal: true

require 'application_system_test_case'

class ProofsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @valid_income_proof = fixture_file_upload('test/fixtures/files/placeholder_income_proof.pdf', 'application/pdf')
    @valid_residency_proof = fixture_file_upload('test/fixtures/files/placeholder_residency_proof.pdf',
                                                 'application/pdf')
  end

  test 'complete application flow with proof submission' do
    # Start at sign in page and click sign up
    visit sign_in_path
    assert_text 'Sign In' # Verify we're on sign in page

    within('p', text: "Don't have an account?") do
      click_on 'Sign Up'
    end

    # Verify we're on the registration page
    assert_text 'Create Account'
    assert_selector 'form' # Verify form exists

    # Fill in registration form
    fill_in 'First Name', with: 'John'
    fill_in 'Last Name', with: 'Smith'
    fill_in 'Email Address', with: 'john.smith@example.com'
    fill_in 'Password', with: 'password123'
    fill_in 'Confirm Password', with: 'password123'
    fill_in 'Phone Number', with: '202-555-1234'
    fill_in 'visible_date_of_birth', with: '01/01/1990'
    select 'English', from: 'Language Preference'
    click_button 'Create Account'

    # Should redirect to welcome page
    assert_current_path welcome_path

    # Navigate to dashboard where Apply Now button is available
    click_on 'Skip and Continue to Dashboard'

    # Start application process
    click_on 'Apply Now'

    # Fill in application form
    check 'I certify that I am a resident of Maryland'
    fill_in 'Household Size', with: '5'
    fill_in 'Annual Income', with: '100000'

    # Fill in address information
    fill_in 'Street Address', with: '123 Main St'
    fill_in 'City', with: 'Baltimore'
    select 'Maryland', from: 'State'
    fill_in 'Zip Code', with: '21201'

    check 'I certify that I have a disability that affects my ability to access telecommunications services'
    check 'Hearing'

    # Fill in medical provider information
    within('section', text: 'Medical Professional Information') do
      fill_in 'Name', with: 'Dr. Feelgood'
      fill_in 'Phone', with: '202-555-5555'
      fill_in 'Fax (Optional)', with: '202-555-5556'
      fill_in 'Email', with: 'drfel@gmail.net'
    end

    # Medical authorization (required)
    check 'I authorize the release and sharing of my medical information as described above'

    # Attach proofs
    attach_file 'Proof of Residency', @valid_residency_proof.path
    attach_file 'Income Verification', @valid_income_proof.path

    # Submit application
    click_button 'Submit Application'

    # Verify we're on the application show page
    assert_text 'Application Details'

    # Verify application details
    assert_text 'Application Type: New'
    assert_text 'Submission Method: Online'
    assert_text 'Status: In Progress'
    assert_text 'Household Size: 5'
    assert_text 'Annual Income: $100,000.00'
    # Check proof statuses in the Uploaded Documents section
    assert_text 'Uploaded Documents'
    assert_text 'Income Proof'
    assert_text 'Residency Proof'
    assert_text 'Not Reviewed'

    # Verify medical provider information
    assert_text 'Medical Provider & Certification'
    assert_text 'Name: Dr. Feelgood'
    assert_text 'Phone: 202-555-5555'
    assert_text 'Email: drfel@gmail.net'

    # Verify action buttons
    assert_link 'See your MAT Dashboard'
  end
end
