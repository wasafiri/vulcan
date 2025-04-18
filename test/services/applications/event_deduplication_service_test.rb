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

        # Create a Notification and a corresponding StatusChange (same event, different sources)
        notification = Notification.create!(
          notifiable: application,
          action: 'medical_certification_requested',
          created_at: time
        )

        status_change = ApplicationStatusChange.create!(
          application: application,
          from_status: 'not_requested',
          to_status: 'requested',
          created_at: time + 5.seconds,
          metadata: { change_type: 'medical_certification' }
        )

        # Execute
        result = service.deduplicate([notification, status_change])

        # Verify: only one event should remain after deduplication
        assert_equal 1, result.size, 'Should have deduplicated to exactly one event'

        # The ApplicationStatusChange should have been kept (has more context)
        assert_equal ApplicationStatusChange, result.first.class
      end
    end
  end
end
