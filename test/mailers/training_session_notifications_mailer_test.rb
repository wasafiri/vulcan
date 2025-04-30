# frozen_string_literal: true

require 'test_helper'
require 'ostruct' # Keep ostruct for the Struct used below

class TrainingSessionNotificationsMailerTest < ActionMailer::TestCase
  # Helper to create mock templates that performs interpolation
  def mock_template(subject_format, body_format)
    template = mock('email_template')
    # Stub render to accept keyword args and perform interpolation
    template.stubs(:render).with(any_parameters).returns do |**vars|
      rendered_subject = subject_format % vars
      rendered_body = body_format % vars
      [rendered_subject, rendered_body]
    end
    template
  end

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

    # Use the mock_template helper for templates
    @trainer_assigned_template = mock_template(
      'Mock New Training Assignment - App %<application_id>s',
      'Mock Body for %<trainer_full_name>s about %<constituent_full_name>s'
    )

    @training_scheduled_template = mock_template(
      'Mock Training Scheduled - App %<application_id>s',
      'Mock Body for %<constituent_name>s with %<trainer_name>s on %<scheduled_date>s'
    )

    @training_completed_template = mock_template(
      'Mock Training Completed - App %<application_id>s',
      'Mock Body for %<constituent_name>s with %<trainer_name>s on %<completion_date>s'
    )

    # Stub EmailTemplate.find_by! for both formats
    EmailTemplate.stubs(:find_by!).with(name: 'training_session_notifications_trainer_assigned',
                                        format: :html).returns(@trainer_assigned_template)
    EmailTemplate.stubs(:find_by!).with(name: 'training_session_notifications_trainer_assigned',
                                        format: :text).returns(@trainer_assigned_template)
    EmailTemplate.stubs(:find_by!).with(name: 'training_session_notifications_training_scheduled',
                                        format: :html).returns(@training_scheduled_template)
    EmailTemplate.stubs(:find_by!).with(name: 'training_session_notifications_training_scheduled',
                                        format: :text).returns(@training_scheduled_template)
    EmailTemplate.stubs(:find_by!).with(name: 'training_session_notifications_training_completed',
                                        format: :html).returns(@training_completed_template)
    EmailTemplate.stubs(:find_by!).with(name: 'training_session_notifications_training_completed',
                                        format: :text).returns(@training_completed_template)
  end

  test 'trainer_assigned' do
    # Use .with() syntax
    email = TrainingSessionNotificationsMailer.with(training_session: @training_session).trainer_assigned

    # No need to stub deliver_notifications if we are just checking the mail object
    # assert_emails 1 do ... end would require it if using deliver_later

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@trainer.email], email.to
    # Assert against the stubbed subject with interpolation
    assert_equal "Mock New Training Assignment - App #{@application.id}", email.subject

    # Check that the email body contains expected interpolated content from the mock
    assert_match "Mock Body for #{@trainer.full_name} about #{@constituent.full_name}", email.html_part.body.to_s
    assert_match "Mock Body for #{@trainer.full_name} about #{@constituent.full_name}", email.text_part.body.to_s
  end

  test 'training_scheduled' do
    # Use .with() syntax
    email = TrainingSessionNotificationsMailer.with(training_session: @training_session).training_scheduled

    # No need to stub deliver_notifications
    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@constituent.email], email.to

    # Assert against the stubbed subject with interpolation
    assert_equal "Mock Training Scheduled - App #{@application.id}", email.subject

    # Verify body contains expected interpolated content from the mock
    expected_date = @scheduled_for.strftime('%B %d, %Y')
    assert_match "Mock Body for #{@constituent.full_name} with #{@trainer.full_name} on #{expected_date}", email.html_part.body.to_s
    assert_match "Mock Body for #{@constituent.full_name} with #{@trainer.full_name} on #{expected_date}", email.text_part.body.to_s
  end

  test 'training_completed' do
    # Use .with() syntax
    # Update the status to completed
    @training_session.status = :completed

    email = TrainingSessionNotificationsMailer.with(training_session: @training_session).training_completed

    # No need to stub deliver_notifications
    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@constituent.email], email.to

    # Assert against the stubbed subject with interpolation
    assert_equal "Mock Training Completed - App #{@application.id}", email.subject

    # Verify body contains expected interpolated content from the mock
    expected_date = @completed_at.strftime('%B %d, %Y')
    assert_match "Mock Body for #{@constituent.full_name} with #{@trainer.full_name} on #{expected_date}", email.html_part.body.to_s
    assert_match "Mock Body for #{@constituent.full_name} with #{@trainer.full_name} on #{expected_date}", email.text_part.body.to_s
  end
end
