require "application_system_test_case"
require_relative "../../support/notification_delivery_stub"

class Admin::AssignTrainerTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin_david)
    @trainer = users(:trainer_jane)
    @evaluator = users(:evaluator_betsy)
    @constituent = users(:constituent_john)
    @admin_with_training_capability = users(:admin_jane) # Admin with can_train capability

    # Create an approved application
    @application = applications(:one)
    @unapproved_application = applications(:two)

    # Include notification delivery stub to avoid real notifications
    Application.include(NotificationDeliveryStub)

    # Set Current.user to avoid validation errors in callbacks
    Current.user = @admin
    @application.update!(status: :approved)
    @unapproved_application.update!(status: :in_progress)

    Current.reset

    # Sign in as admin
    sign_in(@admin)
  end

  teardown do
    Current.reset
  end

  test "admin can assign a trainer to an approved application with no evaluator" do
    # Make sure there are no evaluations for this application
    @application.evaluations.destroy_all

    visit admin_application_path(@application)

    # Verify the page has loaded correctly
    assert_selector "h1", text: "Application ##{@application.id} Details"

    # Verify the application is approved
    assert_selector ".bg-green-100", text: "Approved"

    # Verify the "Assign Trainer" section is visible
    assert_selector "h3", text: "Assign Trainer"

    # Verify the trainer button is displayed
    assert_button "Assign #{@trainer.full_name}"

    # Click the trainer button
    click_button "Assign #{@trainer.full_name}"

    # Verify we're redirected back to the application page
    assert_current_path admin_application_path(@application)

    # Verify the success message
    assert_text "Trainer successfully assigned"

    # Verify the trainer is now displayed
    assert_text @trainer.full_name

    # Verify a notification was created
    assert_equal 1, Notification.where(
      notifiable: @application,
      action: "trainer_assigned"
    ).count
  end

  test "admin can assign a trainer to an approved application with an evaluator already assigned" do
    # Assign an evaluator to the application
    @application.evaluations.destroy_all
    @application.assign_evaluator!(@evaluator)

    visit admin_application_path(@application)

    # Verify the page has loaded correctly
    assert_selector "h1", text: "Application ##{@application.id} Details"

    # Verify the application is approved
    assert_selector ".bg-green-100", text: "Approved"

    # Verify the evaluator is displayed
    assert_text @evaluator.full_name

    # Verify the "Assign Trainer" section is still visible
    assert_selector "h3", text: "Assign Trainer"

    # Verify the trainer button is displayed
    assert_button "Assign #{@trainer.full_name}"

    # Click the trainer button
    click_button "Assign #{@trainer.full_name}"

    # Verify we're redirected back to the application page
    assert_current_path admin_application_path(@application)

    # Verify the success message
    assert_text "Trainer successfully assigned"

    # Verify the trainer is now displayed
    assert_text @trainer.full_name

    # Verify a notification was created
    assert_equal 1, Notification.where(
      notifiable: @application,
      action: "trainer_assigned"
    ).count
  end

  test "admin can assign a user with can_train capability as a trainer" do
    # Skip this test for now as it requires more setup
    skip "This test requires additional setup for role capabilities"
  end

  test "assign trainer section is not visible for unapproved applications" do
    # Ensure the application is not approved
    @unapproved_application.update!(status: :in_progress)

    # Visit the application page
    visit admin_application_path(@unapproved_application)

    # Verify the page has loaded correctly
    assert_selector "h1", text: "Application ##{@unapproved_application.id} Details"

    # Verify the "Assign Trainer" section is not visible
    # This is because the section is only shown for approved applications
    assert_no_selector "h3", text: "Assign Trainer"
  end

  test "trainer assignment creates a training session record" do
    # Make sure there are no evaluations for this application
    @application.evaluations.destroy_all

    # Make sure there are no existing training sessions
    @application.training_sessions.destroy_all

    visit admin_application_path(@application)

    # Click the trainer button
    click_button "Assign #{@trainer.full_name}"

    # Reload the application to get the latest data
    @application.reload

    # Verify a training session was created
    assert_equal 1, @application.training_sessions.count, "Expected one training session to be created"

    # Verify the training session has the correct trainer
    training_session = @application.training_sessions.first
    assert_equal @trainer.id, training_session.trainer_id, "Training session should be assigned to the correct trainer"

    # Verify the training session has the correct status
    assert_equal "scheduled", training_session.status, "Training session should have 'scheduled' status"
  end
end
