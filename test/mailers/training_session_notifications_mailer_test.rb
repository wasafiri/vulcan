# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class TrainingSessionNotificationsMailerTest < ActionMailer::TestCase
  setup do
    # Use factories instead of fixtures
    @constituent = create(:constituent, first_name: 'John', last_name: 'Doe', email: 'john.doe@example.com')
    @trainer = create(:trainer, first_name: 'Jane', last_name: 'Smith', email: 'jane.smith@example.com')
    @application = create(:application, :in_progress, user: @constituent)

    # Create a mock training session with the necessary attributes
    @scheduled_for = 1.week.from_now
    @completed_at = Time.current

    # Stub the training session
    @training_session = Struct.new(
      :application, :trainer, :constituent, :scheduled_for, :completed_at, :status, :id
    ).new(
      @application, @trainer, @constituent, @scheduled_for, @completed_at, :scheduled, 1
    )

    # Create simple template mocks with hardcoded return values
    @training_scheduled_template = OpenStruct.new
    @training_scheduled_template.define_singleton_method(:render) do |**_variables|
      ['Training Session Scheduled', 'Your training is scheduled for a future date and time.']
    end

    @training_completed_template = OpenStruct.new
    @training_completed_template.define_singleton_method(:render) do |**_variables|
      ['Training Session Completed', 'Your training was completed on a previous date.']
    end

    # For the trainer assigned email, no template is used

    # Stub EmailTemplate.find_by! for different template names
    EmailTemplate.stubs(:find_by!).with(name: 'training_scheduled').returns(@training_scheduled_template)
    EmailTemplate.stubs(:find_by!).with(name: 'training_completed').returns(@training_completed_template)
  end

  test 'trainer_assigned' do
    # Stub the NotificationDelivery module to avoid the error
    TrainingSessionNotificationsMailer.any_instance.stubs(:deliver_notifications).returns(true)

    email = TrainingSessionNotificationsMailer.trainer_assigned(@training_session)

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@trainer.email], email.to
    assert_equal "New Training Assignment - Application ##{@application.id}", email.subject

    # Check that the email contains the constituent's contact information
    assert_match @constituent.full_name, email.html_part.body.to_s
    assert_match @constituent.email, email.html_part.body.to_s

    # Check that the email contains instructions to contact the constituent
    assert_match 'Please begin the training process by contacting the constituent', email.html_part.body.to_s
  end

  test 'training_scheduled' do
    # Stub the NotificationDelivery module to avoid the error
    TrainingSessionNotificationsMailer.any_instance.stubs(:deliver_notifications).returns(true)

    email = TrainingSessionNotificationsMailer.training_scheduled(@training_session)

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@constituent.email], email.to

    # Check that the email subject contains "Training Session Scheduled"
    assert_match 'Training Session Scheduled', email.subject

    # Verify it contains trainer's name and some expected text
    assert_match @trainer.full_name, email.html_part.body.to_s
    assert_match 'scheduled', email.html_part.body.to_s
  end

  test 'training_completed' do
    # Stub the NotificationDelivery module to avoid the error
    TrainingSessionNotificationsMailer.any_instance.stubs(:deliver_notifications).returns(true)

    # Update the status to completed
    @training_session.status = :completed

    email = TrainingSessionNotificationsMailer.training_completed(@training_session)

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@constituent.email], email.to

    # Check that the subject contains "Training Session Completed"
    assert_match 'Training Session Completed', email.subject

    # Verify it contains trainer's name and some expected text
    assert_match @trainer.full_name, email.html_part.body.to_s
    assert_match 'completed', email.html_part.body.to_s.downcase
  end
end
