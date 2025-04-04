# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class ActivityTest < ActiveSupport::TestCase
    setup do
      @application = applications(:one)
    end

    test "deduplicate_submissions removes duplicate submissions within the same minute" do
      # Create multiple submissions with same proof type and very close timestamps
      time_base = Time.current
      
      submission1 = ProofSubmissionAudit.new(
        application: @application,
        proof_type: 'income',
        submission_method: 'web',
        created_at: time_base
      )
      
      submission2 = ProofSubmissionAudit.new(
        application: @application,
        proof_type: 'income',
        submission_method: 'web',
        created_at: time_base + 5.seconds
      )
      
      submission3 = ProofSubmissionAudit.new(
        application: @application,
        proof_type: 'income',
        submission_method: 'web',
        created_at: time_base + 10.seconds
      )
      
      # Different proof type should not be deduplicated
      submission4 = ProofSubmissionAudit.new(
        application: @application,
        proof_type: 'residency',
        submission_method: 'web',
        created_at: time_base + 8.seconds
      )
      
      # Different minute should not be deduplicated
      submission5 = ProofSubmissionAudit.new(
        application: @application,
        proof_type: 'income',
        submission_method: 'web',
        created_at: time_base + 1.minute + 5.seconds
      )
      
      submissions = [submission1, submission2, submission3, submission4, submission5]
      
      result = Activity.deduplicate_submissions(submissions)
      
      # Should keep the latest submission from each group
      assert_equal 3, result.size
      
      # The kept income proof from the first minute should be submission3 (the latest)
      income_first_minute = result.find { |s| s.proof_type == 'income' && s.created_at < time_base + 1.minute }
      assert_equal submission3, income_first_minute
      
      # The residency proof should still be there
      assert result.include?(submission4)
      
      # The income proof from the second minute should still be there
      assert result.include?(submission5)
    end
    
    test "from_events returns activities in chronological order" do
      # Create a proof submission and review
      time_base = Time.current
      
      submission = ProofSubmissionAudit.create!(
        application: @application,
        proof_type: 'income',
        submission_method: 'web',
        created_at: time_base - 2.hours
      )
      
      review = ProofReview.create!(
        application: @application,
        admin: users(:admin),
        proof_type: 'income',
        status: 'rejected',
        rejection_reason: "Test rejection reason",
        reviewed_at: time_base - 1.hour,
        created_at: time_base - 1.hour
      )
      
      resubmission = ProofSubmissionAudit.create!(
        application: @application,
        proof_type: 'income',
        submission_method: 'web',
        created_at: time_base - 30.minutes
      )
      
      # Add these to the application
      @application.proof_submission_audits << submission
      @application.proof_submission_audits << resubmission
      @application.proof_reviews << review
      
      activities = Activity.from_events(@application)
      
      # Check order is chronological
      assert_equal 3, activities.size
      assert_equal submission.created_at, activities.first.created_at
      assert_equal review.created_at, activities.second.created_at
      assert_equal resubmission.created_at, activities.third.created_at
      
      # Verify activity types
      assert_equal :submission, activities.first.activity_type
      assert_equal :rejection, activities.second.activity_type
      assert_equal :resubmission, activities.third.activity_type
    end
  end
end
