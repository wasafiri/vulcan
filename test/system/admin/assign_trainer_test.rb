# frozen_string_literal: true

require 'application_system_test_case'

class AssignTrainerTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin_jane)
    @application = applications(:approved_application)
    @trainer = users(:trainer_jane)

    # Sign in as admin
    visit sign_in_path
    fill_in 'Email Address', with: @admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Sign In'
    assert_text 'Dashboard' # Verify we're signed in
  end

  test 'admin can assign trainer to an approved application' do
    # Visit the application show page
    visit admin_application_path(@application)

    # Verify the page has loaded correctly
    assert_text 'Application Details'
    assert_text 'Approved'

    # Verify the "Assign Trainer" section exists
    assert_text 'Assign Trainer'

    # Verify trainer buttons are displayed
    assert_button 'Assign Jane'

    # Click the "Assign Jane" button
    click_button 'Assign Jane'

    # Verify success message
    assert_text 'Trainer successfully assigned'

    # Verify trainer is now displayed in the application details
    assert_text 'Trainer: Jane Trainer'
  end
end
