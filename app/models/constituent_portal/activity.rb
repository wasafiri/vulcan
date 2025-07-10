# frozen_string_literal: true

module ConstituentPortal
  # Activity is a wrapper class that normalizes various activity types
  # (proof submissions, approvals, rejections, etc.) for display in the constituent portal
  class Activity
    include Comparable

    attr_reader :source, :created_at, :activity_type, :proof_type, :description, :details

    # Factory method to create activities from various sources
    def self.from_events(application)
      # Get review activities
      proof_reviews = application.proof_reviews.to_a

      # Process each proof review
      activities = proof_reviews.map do |review|
        from_proof_review(review)
      end

      # Get submission activities and deduplicate
      # Handle both _proof_submitted (constituent portal) and _proof_attached (paper applications)
      submission_events = application.events.where("action LIKE '%_proof_submitted' OR action LIKE '%_proof_attached'").to_a
      deduplicated_submissions = Applications::EventDeduplicationService.new.deduplicate(submission_events)

      # Process each deduplicated submission audit
      deduplicated_submissions.each do |event|
        is_initial = is_initial_submission?(application, event)
        activities << from_submission_event(event, is_initial: is_initial)
      end

      # Sort by creation time (oldest first) and return
      activities.sort_by(&:created_at)
    end

    # Deduplicate submission events within the same minute for the same proof type
    def self.deduplicate_submissions(submissions)
      Applications::EventDeduplicationService.new.deduplicate(submissions)
    end

    # Create an activity from a proof submission event
    def self.from_submission_event(event, is_initial: false)
      proof_type = event.metadata['proof_type']
      submission_method = event.metadata['submission_method'] || 'web'

      # Determine if this is an attached (paper) or submitted (portal) event
      action_verb = event.action.include?('_attached') ? 'attached' : 'submitted'

      new(
        source: event,
        created_at: event.created_at,
        activity_type: is_initial ? :submission : :resubmission,
        proof_type: proof_type.to_sym,
        description: "#{proof_type.to_s.humanize} proof #{action_verb} via #{submission_method}"
      )
    end

    # Create an activity from a proof review
    def self.from_proof_review(review)
      activity_type = review.status_approved? ? :approval : :rejection

      details = (review.rejection_reason.presence || review.notes if review.status_rejected? && (review.rejection_reason.present? || review.notes.present?))

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
    def self.is_initial_submission?(application, event)
      proof_type = event.metadata['proof_type']
      # Handle both submitted and attached events
      action_names = ["#{proof_type}_proof_submitted", "#{proof_type}_proof_attached"]

      # Find all submissions of this type (both submitted and attached)
      same_type_events = application.events
                                    .where(action: action_names)
                                    .order(created_at: :asc)

      # Is this the first one?
      same_type_events.first.id == event.id
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
