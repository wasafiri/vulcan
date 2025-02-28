require "test_helper"

class ApplicationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @admin = users(:admin_david)
    @application = create(:application, :in_progress)
    @proof_review = build(:proof_review,
      application: @application,
      admin: @admin
    )
  end

  test "notifies admins when proofs need review" do
    assert_enqueued_with(job: NotifyAdminsJob) do
      @application.update!(
        income_proof_status: :not_reviewed,
        needs_review_since: Time.current
      )
    end
  end

  test "contacts medical provider when all proofs approved" do
    application = create(:application, :in_progress_with_rejected_proofs)

    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: [
        "MedicalProviderMailer",
        "request_certification",
        "deliver_now",
        { args: [ application ] }
      ]
    ) do
      create(:proof_review,
        application: application,
        admin: @admin,
        proof_type: :income,
        status: :approved
      )
      create(:proof_review,
        application: application,
        admin: @admin,
        proof_type: :residency,
        status: :approved
      )
    end

    application.reload
    assert application.all_proofs_approved?
  end

  test "log_status_change uses application user when Current.user is nil" do
    # Create an application with a known user
    application = create(:application, :draft)
    constituent = application.user

    # Store the initial event count
    initial_event_count = Event.count

    # Ensure Current.user is nil
    Current.user = nil

    # Change the application status to trigger log_status_change
    application.update!(status: :in_progress)

    # Verify an event was created
    assert_equal initial_event_count + 1, Event.count

    # Get the latest event
    event = Event.last

    # Verify the event was created with the application's user
    assert_equal constituent.id, event.user_id
    assert_equal "application_status_changed", event.action
    assert_equal application.id, event.metadata["application_id"]
    assert_equal "draft", event.metadata["old_status"]
    assert_equal "in_progress", event.metadata["new_status"]
  end

  test "log_status_change uses Current.user when available" do
    # Create an application
    application = create(:application, :draft)

    # Store the initial event count
    initial_event_count = Event.count

    # Set Current.user to an admin
    Current.user = @admin

    # Change the application status to trigger log_status_change
    application.update!(status: :in_progress)

    # Verify an event was created
    assert_equal initial_event_count + 1, Event.count

    # Get the latest event
    event = Event.last

    # Verify the event was created with Current.user
    assert_equal @admin.id, event.user_id
    assert_equal "application_status_changed", event.action
    assert_equal application.id, event.metadata["application_id"]
    assert_equal "draft", event.metadata["old_status"]
    assert_equal "in_progress", event.metadata["new_status"]

    # Reset Current.user to avoid affecting other tests
    Current.user = nil
  end
end
