# frozen_string_literal: true

require 'test_helper'

module Applications
  class EventDeduplicationServiceTest < ActiveSupport::TestCase
    setup do
      # Set up mocks for ActiveStorage attachments to prevent byte_size() errors
      setup_attachment_mocks_for_audit_logs
    end

    test 'correctly deduplicates events' do
      assert_test_has_assertions

      with_mocked_attachments do
        # Setup
        application = applications(:complete)
        prepare_application_for_test(application,
                                    status: 'approved',
                                    income_proof_status: 'approved',
                                    residency_proof_status: 'approved')

        service = EventDeduplicationService.new

        # Create test scenario with key duplicates:
        time = Time.current

        # Create an Event for medical certification requested (simulating AuditEventService.log)
        event1 = AuditEventService.log(
          action: 'medical_certification_requested',
          actor: application.user,
          auditable: application,
          created_at: time,
          metadata: { provider_name: 'Dr. Test' }
        )

        # Create a corresponding ApplicationStatusChange (same underlying event, different source)
        status_change = ApplicationStatusChange.create!(
          application: application,
          user: application.user,
          from_status: 'not_requested',
          to_status: 'requested',
          created_at: time + 5.seconds,
          metadata: { change_type: 'medical_certification', provider_name: 'Dr. Test' }
        )

        # Execute
        result = service.deduplicate([event1, status_change])

        # Verify: only one event should remain after deduplication
        assert_equal 1, result.size, 'Should have deduplicated to exactly one event'

        # The ApplicationStatusChange should have been kept (has more context and is preferred)
        assert_equal ApplicationStatusChange, result.first.class
        assert_equal status_change.id, result.first.id
      end
    end
  end
end
