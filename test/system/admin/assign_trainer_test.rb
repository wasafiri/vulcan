# frozen_string_literal: true

require 'application_system_test_case'

class AssignTrainerTest < ApplicationSystemTestCase
  setup do
    @admin = create(:admin)
    @application = create(:application, :completed) # Use :completed instead of :approved
    @trainer = create(:user, :trainer, first_name: 'Jane', last_name: 'Trainer')

    # Set up policy to allow training sessions
    Policy.find_or_create_by(key: 'max_training_sessions').update(value: 2)

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
    assert_button "Assign #{@trainer.first_name}"

    # Click the trainer assignment button
    click_button "Assign #{@trainer.first_name}"

    # Verify success message
    assert_text 'Trainer successfully assigned'

    # Verify trainer is now displayed in the application details
    assert_text 'Current Trainer'
    assert_text @trainer.full_name
  end
end
