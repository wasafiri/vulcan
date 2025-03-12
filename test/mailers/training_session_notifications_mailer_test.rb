require "test_helper"

class TrainingSessionNotificationsMailerTest < ActionMailer::TestCase
  setup do
    # Use fixtures directly
    @constituent = users(:constituent_john)
    @trainer = users(:trainer_jane)
    @application = applications(:two)

    # Create a mock training session with the necessary attributes
    @scheduled_for = 1.week.from_now
    @completed_at = Time.current

    # Stub the training session
    @training_session = Struct.new(
      :application, :trainer, :constituent, :scheduled_for, :completed_at, :status
    ).new(
      @application, @trainer, @constituent, @scheduled_for, @completed_at, :scheduled
    )
  end

  test "trainer_assigned" do
    # Stub the NotificationDelivery module to avoid the error
    TrainingSessionNotificationsMailer.any_instance.stubs(:deliver_notifications).returns(true)

    email = TrainingSessionNotificationsMailer.trainer_assigned(@training_session)

    assert_equal [ "no_reply@mdmat.org" ], email.from
    assert_equal [ @trainer.email ], email.to
    assert_equal "New Training Assignment - Application ##{@application.id}", email.subject

    # Check that the email contains the constituent's contact information
    assert_match @constituent.full_name, email.html_part.body.to_s
    assert_match @constituent.email, email.html_part.body.to_s

    # Check that the email contains instructions to contact the constituent
    assert_match "Please begin the training process by contacting the constituent", email.html_part.body.to_s
  end

  test "training_scheduled" do
    # Stub the NotificationDelivery module to avoid the error
    TrainingSessionNotificationsMailer.any_instance.stubs(:deliver_notifications).returns(true)

    # Create a template for the test
    EmailTemplate.find_or_create_by!(
      name: "training_scheduled"
    ) do |t|
      t.subject = "Training Session Scheduled"
      t.body = "Your training is scheduled for {{scheduled_date}} at {{scheduled_time}}."
    end

    email = TrainingSessionNotificationsMailer.training_scheduled(@training_session)

    assert_equal [ "no_reply@mdmat.org" ], email.from
    assert_equal [ @constituent.email ], email.to

    # Check that the subject contains "Training Session Scheduled"
    assert_match "Training Session Scheduled", email.subject

    # Check that the email body contains the scheduled date
    scheduled_date = @training_session.scheduled_for.strftime("%B %d, %Y")
    assert_match scheduled_date, email.html_part.body.to_s
  end

  test "training_completed" do
    # Stub the NotificationDelivery module to avoid the error
    TrainingSessionNotificationsMailer.any_instance.stubs(:deliver_notifications).returns(true)

    # Create a template for the test
    EmailTemplate.find_or_create_by!(
      name: "training_completed"
    ) do |t|
      t.subject = "Training Session Completed"
      t.body = "Your training was completed on {{completion_date}}."
    end

    # Update the status to completed
    @training_session.status = :completed

    email = TrainingSessionNotificationsMailer.training_completed(@training_session)

    assert_equal [ "no_reply@mdmat.org" ], email.from
    assert_equal [ @constituent.email ], email.to

    # Check that the subject contains "Training Session Completed"
    assert_match "Training Session Completed", email.subject

    # Check that the email body contains the completion date
    completion_date = @training_session.completed_at.strftime("%B %d, %Y")
    assert_match completion_date, email.html_part.body.to_s
  end
end
