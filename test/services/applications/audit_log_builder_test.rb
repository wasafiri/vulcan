require 'test_helper'

module Applications
  class AuditLogBuilderTest < ActiveSupport::TestCase
    setup do
      @application = applications(:complete)
      prepare_application_for_test(@application, 
                                  status: 'approved', 
                                  income_proof_status: 'approved',
                                  residency_proof_status: 'approved')
      
      @admin = users(:admin)
      @user = users(:confirmed_user)
      
      # Create some test data that we can verify in our audit logs
      @status_change = ApplicationStatusChange.create!(
        application: @application,
        user: @admin,
        from_status: 'draft',
        to_status: 'submitted'
      )
      
      @proof_review = ProofReview.create!(
        application: @application,
        admin: @admin,
        proof_type: 'income',
        status: 'approved',
        reviewed_at: Time.current
      )
      
      @notification = Notification.create!(
        recipient: @user,
        actor: @admin,
        notifiable: @application,
        action: 'proof_approved',
        read_at: nil
      )
      
      @event = Event.create!(
        user: @admin,
        action: 'application_created',
        metadata: { application_id: @application.id }
      )
    end
    
    test "builds audit logs from all sources" do
      builder = AuditLogBuilder.new(@application)
      logs = builder.build_audit_logs
      
      # Verify we have all the expected log entries
      assert_includes logs, @status_change
      assert_includes logs, @proof_review
      assert_includes logs.map(&:__getobj__), @notification # Check the decorated notification
      assert_includes logs, @event
      
      # Verify they're sorted by created_at in descending order
      assert_equal logs.map(&:created_at), logs.map(&:created_at).sort.reverse
    end
    
    test "returns empty array when application is nil" do
      builder = AuditLogBuilder.new(nil)
      assert_empty builder.build_audit_logs
    end
    
    test "handles exceptions gracefully" do
      # Mock a method to raise an exception
      ProofReview.stub :where, ->(*_args) { raise StandardError, "Test error" } do
        builder = AuditLogBuilder.new(@application)
        
        # It should return an empty array and add an error
        assert_empty builder.build_audit_logs
        assert_includes builder.errors, "Failed to build audit logs: Test error"
      end
    end
  end
end
