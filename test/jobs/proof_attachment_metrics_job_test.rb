# frozen_string_literal: true

require 'test_helper'

class ProofAttachmentMetricsJobTest < ActiveJob::TestCase
  setup do
    # Clear all notifications and events
    Notification.delete_all
    Event.delete_all

    # Create test application and admin using factories instead of fixtures
    @application = create(:application, skip_proofs: true) # Skip default proof attachments
    @admin = create(:admin)

    # Create some successful events using AuditEventService
    8.times do |i|
      AuditEventService.log(
        action: 'proof_submitted',
        actor: @application.user,
        auditable: @application,
        metadata: {
          proof_type: i < 4 ? 'income' : 'residency',
          submission_method: i.even? ? 'web' : 'paper',
          success: true,
          timestamp: Time.current.iso8601
        }
      )
    end

    # Create some failure events using AuditEventService
    2.times do |i|
      AuditEventService.log(
        action: 'proof_submitted',
        actor: @application.user,
        auditable: @application,
        metadata: {
          proof_type: 'income',
          submission_method: 'web',
          success: false,
          error_message: "Test error #{i}",
          timestamp: Time.current.iso8601
        }
      )
    end

    # Ensure we have old events that shouldn't be counted
    AuditEventService.log(
      action: 'proof_submitted',
      actor: @application.user,
      auditable: @application,
      metadata: {
        proof_type: 'income',
        submission_method: 'web',
        success: false,
        error_message: 'Old error',
        timestamp: 2.days.ago.iso8601
      },
      created_at: 2.days.ago # Manually set created_at for old event
    )
  end

  test 'processes metrics correctly' do
    assert_equal 10, Event.where(action: 'proof_submitted').where('created_at > ?', 24.hours.ago).count
    assert_equal 2, Event.where(action: 'proof_submitted').where('created_at > ?', 24.hours.ago)
                                        .where("metadata->>'success' = ?", 'false').count

    # Make sure no notifications exist yet
    assert_equal 0, Notification.count

    # Run the job
    ProofAttachmentMetricsJob.perform_now

    # Since success rate is 80%, which is below 95% threshold with more than 5 failures,
    # it should create notifications for admins
    assert_equal 1, Notification.count, 'Should have created 1 notification'

    notification = Notification.first
    assert_equal @admin, notification.recipient
    assert_equal 'attachment_failure_warning', notification.action
    assert_equal 80.0, notification.metadata['success_rate']
    assert_equal 10, notification.metadata['total']
    assert_equal 2, notification.metadata['failed']
  end

  test "doesn't create notifications when success rate is good" do
    # Delete the failure events
    Event.where(action: 'proof_submitted').where("metadata->>'success' = ?", 'false').delete_all

    # Run the job
    ProofAttachmentMetricsJob.perform_now

    # Should not create notifications since success rate is 100%
    assert_equal 0, Notification.count, 'Should not have created notifications'
  end

  test "doesn't create notifications with too few failures" do
    # Delete one failure to get below threshold of 5
    Event.where(action: 'proof_submitted').where("metadata->>'success' = ?", 'false').first.destroy

    # Run the job
    ProofAttachmentMetricsJob.perform_now

    # Should not create notifications since we have fewer than 5 failures
    assert_equal 0, Notification.count, 'Should not have created notifications'
  end

  test 'handles empty audit data' do
    # Delete all events
    Event.delete_all

    # Run the job - should not raise any errors
    assert_nothing_raised do
      ProofAttachmentMetricsJob.perform_now
    end

    # Should not create notifications
    assert_equal 0, Notification.count
  end
end
