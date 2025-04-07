# frozen_string_literal: true
require 'test_helper'

module Applications
  class EventDeduplicationServiceTest < ActiveSupport::TestCase
    test "correctly deduplicates events" do
      # Setup
      application = applications(:complete)
      service = EventDeduplicationService.new
      
      # Create test scenario with key duplicates:
      time = Time.current
      
      # Create a Notification and a corresponding StatusChange (same event, different sources)
      notification = Notification.create!(
        notifiable: application,
        action: "medical_certification_requested",
        created_at: time
      )
      
      status_change = ApplicationStatusChange.create!(
        application: application,
        from_status: "not_requested",
        to_status: "requested",
        created_at: time + 5.seconds,
        metadata: { change_type: 'medical_certification' }
      )
      
      # Execute
      result = service.deduplicate([notification, status_change])
      
      # Verify: only one event should remain after deduplication
      assert_equal 1, result.size, "Should have deduplicated to exactly one event"
      
      # The ApplicationStatusChange should have been kept (has more context)
      assert_equal ApplicationStatusChange, result.first.class
    end
  end
end
