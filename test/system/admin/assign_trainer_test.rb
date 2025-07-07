# frozen_string_literal: true

require 'application_system_test_case'

class AssignTrainerTest < ApplicationSystemTestCase
  setup do
    @admin = create(:admin)
    @application = create(:application, :approved)
    @trainer = create(:user, :trainer)

    # Sign in as admin via system test helper for reliability
    system_test_sign_in(@admin)
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
    assert_text 'Current Trainer'
    assert_text 'Jane Trainer'
  end
end
