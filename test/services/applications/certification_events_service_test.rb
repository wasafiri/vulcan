# frozen_string_literal: true

require 'test_helper'

module Applications
  class CertificationEventsServiceTest < ActiveSupport::TestCase
    setup do
      @application = create(:application, status: :in_progress)
      @admin = create(:admin)

      # Create sample event data for testing
      @notification = Notification.create!( # Keep this as Notification for now, as AuditLogBuilder still loads Notifications
        recipient: @application.user,
        actor: @admin,
        action: 'medical_certification_requested',
        notifiable: @application,
        metadata: { timestamp: 1.day.ago.iso8601, submission_method: 'email' }
      )

      @status_change = ApplicationStatusChange.create!(
        application: @application,
        user: @admin,
        from_status: 'submitted',
        to_status: 'requested',
        metadata: { change_type: 'medical_certification' }
      )

      @event = AuditEventService.log( # Use AuditEventService.log for Event creation
        action: 'medical_certification_requested',
        actor: @admin,
        auditable: @application,
        metadata: {
          details: 'certification requested via admin',
          submission_method: 'fax'
        }
      )

      # Create a non-certification event to test filtering
      @unrelated_event = AuditEventService.log( # Use AuditEventService.log for Event creation
        action: 'application_created',
        actor: @admin,
        auditable: @application,
        metadata: { initial_status: 'in_progress' }
      )

      # Initialize our service
      @service = CertificationEventsService.new(@application)
    end

    test 'certification_events returns only certification-related events' do
      with_mocked_attachments do
        events = @service.certification_events

        # Should include our certification-related events
        assert_includes events, @notification
        assert_includes events, @status_change
        assert_includes events, @event

        # Should NOT include unrelated events
        assert_not_includes events, @unrelated_event

        # Should return the correct count
        assert_equal 3, events.count
      end
    end

    test 'request_events returns processed request events' do
      with_mocked_attachments do
        request_events = @service.request_events

        # The events should be processed into a specific format
        assert_instance_of Array, request_events
        assert((request_events.all? { |e| e.is_a?(Hash) }))

        # Verify we have the expected number of events (may be less than 3 due to deduplication)
        assert request_events.present?

        # Verify the format of a request event
        event = request_events.first
        assert event.key?(:timestamp)
        assert event.key?(:actor_name)
        assert event.key?(:submission_method)

        # Test deduplication - events with the same timestamp should be combined
        # Create another event via AuditEventService.log for deduplication test
        AuditEventService.log(
          action: 'medical_certification_requested',
          actor: @admin,
          auditable: @application,
          metadata: { timestamp: @notification.metadata['timestamp'] } # Same timestamp
        )

        # Service should be recreated to get fresh events
        service = CertificationEventsService.new(@application)
        new_request_events = service.request_events

        # Count should not increase due to deduplication
        assert_equal request_events.count, new_request_events.count
      end
    end

    test 'deduplication preserves submission method when available' do
      with_mocked_attachments do
        # Create events with the same timestamp but one has submission method
        same_time = Time.current.iso8601

        # Create an event without submission_method
        AuditEventService.log(
          action: 'medical_certification_requested',
          actor: @admin,
          auditable: @application,
          metadata: { timestamp: same_time }
        )

        # Create an event with submission_method
        AuditEventService.log(
          action: 'medical_certification_requested',
          actor: @admin,
          auditable: @application,
          metadata: { timestamp: same_time, submission_method: 'portal' }
        )

        service = CertificationEventsService.new(@application)
        processed_events = service.request_events

        # Find the event with our timestamp
        target_event = processed_events.find { |e| e[:timestamp].iso8601 == same_time }
        assert_not_nil target_event

        # It should have the submission method from the event that had one
        assert_equal 'portal', target_event[:submission_method]
      end
    end
  end
end
