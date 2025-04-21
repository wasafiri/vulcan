# frozen_string_literal: true

module ConstituentPortal
  # Activity is a wrapper class that normalizes various activity types
  # (proof submissions, approvals, rejections, etc.) for display in the constituent portal
  class Activity
    include Comparable

    attr_reader :source, :created_at, :activity_type, :proof_type, :description, :details

    # Factory method to create activities from various sources
    def self.from_events(application)
      activities = []

      # Get review activities
      proof_reviews = application.proof_reviews.to_a

      # Process each proof review
      proof_reviews.each do |review|
        activities << from_proof_review(review)
      end

      # Get submission activities and deduplicate
      deduplicated_submissions = deduplicate_submissions(application.proof_submission_audits.to_a)

      # Process each deduplicated submission audit
      deduplicated_submissions.each do |audit|
        is_initial = is_initial_submission?(application, audit)
        activities << from_submission_audit(audit, is_initial)
      end

      # Sort by creation time (oldest first) and return
      activities.sort_by(&:created_at)
    end

    # Deduplicate submission audits by grouping closely timed submissions
    # that have the same proof type and submission method
    def self.deduplicate_submissions(submissions)
      return [] if submissions.blank?

      # Group submissions by a fingerprint to identify duplicates
      grouped_submissions = submissions.group_by do |submission|
        # Create a fingerprint using proof type, submission method,
        # and the timestamp rounded to the minute
        rounded_time = submission.created_at.beginning_of_minute
        [
          submission.proof_type,
          submission.submission_method,
          rounded_time
        ]
      end

      # For each group of matching submissions, take only the latest one
      grouped_submissions.map do |_, group|
        group.max_by(&:created_at)
      end
    end

    # Create an activity from a proof submission audit
    def self.from_submission_audit(audit, is_initial = false)
      new(
        source: audit,
        created_at: audit.created_at,
        activity_type: is_initial ? :submission : :resubmission,
        proof_type: audit.proof_type.to_sym,
        description: "#{audit.proof_type.to_s.humanize} proof #{is_initial ? 'submitted' : 'resubmitted'} via #{audit.submission_method}"
      )
    end

    # Create an activity from a proof review
    def self.from_proof_review(review)
      activity_type = review.status_approved? ? :approval : :rejection

      details = if review.status_rejected? && (review.rejection_reason.present? || review.notes.present?)
                  review.rejection_reason.presence || review.notes
                end

      new(
        source: review,
        created_at: review.created_at,
        activity_type: activity_type,
        proof_type: review.proof_type.to_sym,
        description: "#{review.proof_type.to_s.humanize} proof #{review.status_approved? ? 'approved' : 'rejected'}",
        details: details
      )
    end

    # Determine if a submission is the initial one for its proof type
    def self.is_initial_submission?(application, audit)
      # Find all submissions of this type
      same_type_audits = application.proof_submission_audits
                                    .where(proof_type: audit.proof_type)
                                    .order(created_at: :asc)

      # Is this the first one?
      same_type_audits.first.id == audit.id
    end

    # Initialize a new activity
    def initialize(source:, created_at:, activity_type:, proof_type:, description:, details: nil)
      @source = source
      @created_at = created_at
      @activity_type = activity_type
      @proof_type = proof_type
      @description = description
      @details = details
    end

    # Support comparison for sorting
    def <=>(other)
      created_at <=> other.created_at
    end

    # Icon CSS class based on activity type
    def icon_class
      case activity_type
      when :submission, :resubmission
        'text-blue-600'
      when :approval
        'text-green-600'
      when :rejection
        'text-red-600'
      else
        'text-gray-500'
      end
    end

    # Icon symbol based on activity type
    def icon_symbol
      case activity_type
      when :submission, :resubmission
        '→'
      when :approval
        '✓'
      when :rejection
        '×'
      else
        '•'
      end
    end
  end
end
