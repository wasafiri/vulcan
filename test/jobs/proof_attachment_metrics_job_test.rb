# frozen_string_literal: true

require 'test_helper'

class ProofAttachmentMetricsJobTest < ActiveJob::TestCase
  setup do
    # Clear all notifications and events
    Notification.delete_all
    Event.delete_all

    # Clear only admin users to ensure clean test environment for notifications
    # Handle foreign key constraints by clearing dependent records first
    ProofReview.where(admin: User.where(type: 'Users::Administrator')).delete_all
    User.where(type: 'Users::Administrator').delete_all

    # Create test application and admins using factories instead of fixtures
    @application = create(:application, skip_proofs: true) # Skip default proof attachments

    # Create multiple admins to test notification distribution
    @admin1 = create(:admin)
    @admin2 = create(:admin)
    @admin3 = create(:admin)

    # Create some successful events using the actions the job actually looks for
    # Spread them out more to avoid deduplication and make each unique
    base_time = Time.current
    8.times do |i|
      action_name = i < 4 ? 'income_proof_attached' : 'residency_proof_attached'
      Event.create!(
        action: action_name,
        user: @application.user,
        auditable: @application,
        metadata: {
          proof_type: i < 4 ? 'income' : 'residency',
          submission_method: i.even? ? 'web' : 'paper',
          success: true,
          timestamp: (base_time - (i * 5).minutes).iso8601
        },
        created_at: base_time - (i * 5).minutes
      )
    end

    # Create some failure events using the actions the job actually looks for
    6.times do |i|
      action_name = i < 3 ? 'income_proof_attachment_failed' : 'residency_proof_attachment_failed'
      Event.create!(
        action: action_name,
        user: @application.user,
        auditable: @application,
        metadata: {
          proof_type: i < 3 ? 'income' : 'residency',
          submission_method: 'web',
          success: false,
          error_message: "Test error #{i}",
          timestamp: (base_time - ((8 + i) * 2).minutes).iso8601
        },
        created_at: base_time - ((8 + i) * 2).minutes
      )
    end

    # Ensure we have old events that shouldn't be counted
    Event.create!(
      action: 'income_proof_attachment_failed',
      user: @application.user,
      auditable: @application,
      metadata: {
        proof_type: 'income',
        submission_method: 'web',
        success: false,
        error_message: 'Old error',
        timestamp: 2.days.ago.iso8601
      },
      created_at: 2.days.ago
    )
  end

  test 'processes metrics correctly' do
    # Check that we have the right number of attachment events
    attachment_actions = %w[
      income_proof_attached residency_proof_attached
      income_proof_attachment_failed residency_proof_attachment_failed
    ]
    recent_events = Event.where(action: attachment_actions).where('created_at > ?', 24.hours.ago)
    assert_equal 14, recent_events.count # 8 successful + 6 failed

    failed_events = recent_events.where("action LIKE '%_failed'")
    assert_equal 6, failed_events.count

    # Make sure no notifications exist yet
    assert_equal 0, Notification.count

    # Run the job
    ProofAttachmentMetricsJob.perform_now

    # Since success rate is 57.1% (8/14), which is below 95% threshold with 6 failures (> 5),
    # it should create notifications for admins (one per admin)
    # We created 3 admins in setup, plus the job creates a system user (also admin type)
    # So we should get 4 notifications total
    assert_equal 4, Notification.count, 'Should have created 4 notifications (one per admin including system user)'

    # Check that each notification has the correct content
    Notification.find_each do |notification|
      assert_equal 'attachment_failure_warning', notification.action
      assert_equal 57.1, notification.metadata['success_rate']
      assert_equal 14, notification.metadata['total']
      assert_equal 6, notification.metadata['failed']
      assert notification.recipient.admin?, 'Recipient should be an admin'
    end
  end

  test "doesn't create notifications when success rate is good" do
    # Delete the failure events
    Event.where("action LIKE '%_failed'").delete_all

    # Run the job
    ProofAttachmentMetricsJob.perform_now

    # Should not create notifications since success rate is 100%
    assert_equal 0, Notification.count, 'Should not have created notifications'
  end

  test "doesn't create notifications with too few failures" do
    # Delete enough failure events to get below threshold of 5
    Event.where("action LIKE '%_failed'").limit(2).destroy_all

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
