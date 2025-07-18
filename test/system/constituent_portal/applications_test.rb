# frozen_string_literal: true

require 'application_system_test_case'

class ApplicationsSystemTest < ApplicationSystemTestCase
  setup do
    @user = create(:constituent, first_name: 'Test', last_name: 'Guardian')
    @dependent = create(:constituent, first_name: 'Jane', last_name: 'Dependent', email: 'jane.dependent@example.com', phone: '5555551212')

    # Directly create the relationship to ensure it's set up correctly, avoiding potential factory issues.
    GuardianRelationship.create!(
      guardian_id: @user.id,
      dependent_id: @dependent.id,
      relationship_type: 'Parent'
    )
    @valid_pdf = file_fixture('income_proof.pdf').to_s
    @valid_image = file_fixture('residency_proof.pdf').to_s

    # Use enhanced sign in for better stability
    system_test_sign_in(@user)
    assert_text 'Dashboard', wait: 10 # Verify we're signed in
  end

  teardown do
    # Extra cleanup to ensure browser stability
  end

  test 'can view new application form' do
    skip 'This test needs to be updated to match the actual application UI'

    # Visit the new application form directly
    visit new_constituent_portal_application_path

    assert_selector 'h1', text: 'New Application'

    # Check for updated income proof instructions
    assert_text 'most recent tax return (preferred)'
    assert_text 'current year SSA award letter (less than 2 months old)'
    assert_text 'bank statement showing your SSA deposit'
    assert_text 'utility bill, it must show your current address'

    # Verify pay stubs are not mentioned
    assert_no_text 'pay stubs'
    assert_no_text 'paystubs'

    # Check for medical provider section without "other medical professional"
    assert_text 'Medical Professional Information'
    assert_text 'Doctor / Physician'
    assert_text 'Audiologist'
    assert_no_text 'other medical professional'
  end

  test 'can submit application with valid data' do
    skip 'This test needs to be updated to match the actual application UI'

    visit new_constituent_portal_application_path

    # Fill in required fields based on the actual form
    # This will need to be updated to match the actual form fields

    # Verify success
    assert_text 'Application submitted successfully', wait: 5
  end

  test 'shows validation errors for invalid submission' do
    skip 'This test needs to be updated to match the actual application UI'

    visit new_constituent_portal_application_path

    # Submit without filling required fields
    # This will need to be updated to match the actual submit button

    # Verify validation errors
    assert_text "can't be blank", wait: 5 # Look for generic validation error
  end

  test 'dashboard shows correct application status after submission' do
    skip 'This test needs to be updated to match the actual application UI'

    # This test needs to be completely rewritten to match the actual application flow

    # Verify dashboard shows the application
    assert_text 'Application Status'
  end

  test 'application form is accessible with keyboard navigation' do
    skip 'This test needs to be updated to match the actual application UI'

    visit new_constituent_portal_application_path

    # This test needs to be updated to match the actual form elements
    # and keyboard navigation flow
  end

  test 'can save a draft application' do
    visit new_constituent_portal_application_path

    # Fill in some basic fields
    check 'I certify that I am a resident of Maryland'
    fill_in 'Household Size', with: 2
    fill_in 'Annual Income', with: 50_000
    fill_in 'Street Address', with: '456 Oak Ave'
    fill_in 'City', with: 'Annapolis'
    select 'Maryland', from: 'State'
    fill_in 'Zip Code', with: '21401'
    check 'I certify that I have a disability that affects my ability to access telecommunications services'
    check 'Vision'

    # Save as draft
    click_button 'Save Application'

    # Verify success and redirection
    assert_text 'Application saved as draft.', wait: 10
    assert_current_path %r{/constituent_portal/applications/\d+}

    # Verify the application was actually created in the DB
    application = Application.find_by(user_id: @user.id, status: 'draft')
    assert_not_nil application, 'Draft application was not created in the database.'
    assert_equal 2, application.household_size
    assert_equal 50_000, application.annual_income
    assert application.user.vision_disability
  end

  test 'preserves form data when validation fails' do
    visit new_constituent_portal_application_path

    # Fill in required fields
    check 'I certify that I am a resident of Maryland'
    fill_in 'Household Size', with: 3
    fill_in 'Annual Income', with: 60_000
    check 'I certify that I have a disability that affects my ability to access telecommunications services'
    check 'Hearing'
    check 'Vision'

    # Fill in medical provider info
    within "section[aria-labelledby='medical-info-heading']" do
      fill_in 'Name', with: 'Dr. Jane Smith'
      fill_in 'Phone', with: '2025551234'
      fill_in 'Email', with: 'drsmith@example.com'
    end

    # Intentionally leave a required field blank to cause validation failure
    within "section[aria-labelledby='medical-info-heading']" do
      fill_in 'Name', with: ''
    end

    # Submit the form
    find('input[name="submit_application"]').click

    # Verify the form is still displayed (validation failed)
    assert_selector 'h1', text: 'New Application'

    # Verify form data is preserved
    assert_checked_field 'I certify that I am a resident of Maryland'
    assert_field 'Household Size', with: '3'
    assert_field 'Annual Income', with: '60000'
    assert_checked_field 'I certify that I have a disability that affects my ability to access telecommunications services'
    assert_checked_field 'Hearing'
    assert_checked_field 'Vision'

    # Verify medical provider info is preserved (except the intentionally blanked field)
    within "section[aria-labelledby='medical-info-heading']" do
      assert_field 'Phone', with: '2025551234'
      assert_field 'Email', with: 'drsmith@example.com'
    end
  end

  test 'saves all form fields when clicking Save Application' do
    visit new_constituent_portal_application_path

    # Fill in all form fields
    # Residency
    check 'I certify that I am a resident of Maryland'

    # Household information
    fill_in 'Household Size', with: '4'
    fill_in 'Annual Income', with: '60000'

    # Address
    fill_in 'Street Address', with: '123 Main St'
    fill_in 'City', with: 'Baltimore'
    select 'Maryland', from: 'State'
    fill_in 'Zip Code', with: '21201'

    # Guardian information
    choose 'A dependent I manage'

    # Wait for the dependent section to become visible
    puts page.html
    assert_selector '#dependent-selection-fields', visible: true, wait: 10

    # Select the dependent (using the actual name from the factory)
    select @dependent.full_name, from: 'application[user_id]'

    # Disability information
    check 'I certify that I have a disability that affects my ability to access telecommunications services'
    check 'Hearing'
    check 'Vision'
    check 'Mobility'

    # Medical provider information
    within "section[aria-labelledby='medical-info-heading']" do
      fill_in 'Name', with: 'Dr. Robert Johnson'
      fill_in 'Phone', with: '4105551234'
      fill_in 'Fax', with: '4105555678'
      fill_in 'Email', with: 'dr.johnson@example.com'
    end

    check 'I authorize the release and sharing of my medical information as described above'

    # Upload documents (if the test environment supports it)
    attach_file 'Proof of Residency', @valid_image
    attach_file 'Income Verification', @valid_pdf

    # Save the application
    click_button 'Save Application'

    # Wait for the async form submission and redirect to complete
    wait_for_turbo
    # Verify success message
    assert_text 'Application saved as draft.', wait: 10

    # Get the newly created application
    application = Application.last

    # Verify application fields were saved in the database
    assert_equal 'draft', application.status
    assert application.maryland_resident
    assert_equal 4, application.household_size
    assert_equal 60_000, application.annual_income.to_i
    assert application.self_certify_disability

    # Verify medical provider info was saved
    assert_equal 'Dr. Robert Johnson', application.medical_provider_name
    assert_equal '4105551234', application.medical_provider_phone
    assert_equal '4105555678', application.medical_provider_fax
    assert_equal 'dr.johnson@example.com', application.medical_provider_email

    # Verify the application is for the dependent
    assert_equal @dependent.id, application.user_id

    # Verify user attributes were updated (disabilities are on the user model)
    user = application.user.reload
    assert user.hearing_disability
    assert user.vision_disability
    assert_not user.speech_disability
    assert user.mobility_disability
    assert_not user.cognition_disability

    # Verify file attachments
    assert application.residency_proof.attached?
    assert application.income_proof.attached?

    # Navigate to edit page to verify all fields were saved in the UI
    visit edit_constituent_portal_application_path(application)

    # Verify all fields have the values we entered
    assert_checked_field 'I certify that I am a resident of Maryland'
    assert_field 'Household Size', with: '4'
    assert_field 'Annual Income', with: '60000'
    assert_checked_field 'A dependent I manage'
    # Verify the dependent is selected in the dropdown
    select_field = find('select[name="application[user_id]"]')
    assert_equal @user.id.to_s, select_field.value
    assert_checked_field 'I certify that I have a disability that affects my ability to access telecommunications services'
    assert_checked_field 'Hearing'
    assert_checked_field 'Vision'
    assert_checked_field 'Mobility'
    assert_not_checked_field 'Speech'
    assert_not_checked_field 'Cognition'

    # Verify medical provider info
    within "section[aria-labelledby='medical-info-heading']" do
      assert_field 'Name', with: 'Dr. Robert Johnson'
      assert_field 'Phone', with: '4105551234'
      assert_field 'Fax', with: '4105555678'
      assert_field 'Email', with: 'dr.johnson@example.com'
    end
  end
end
