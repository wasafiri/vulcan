# frozen_string_literal: true

module Applications
  # Service to handle application event creation and tracking
  # This service ensures events are created correctly and consistently
  class EventService < BaseService
    attr_reader :application, :user

    def initialize(application, user: nil)
      super()
      @application = application
      @user = user || application.user
    end

    # Create a guardian application update event
    # This checks if only nested user attributes changed to avoid duplicate events
    # @param guardian_relationship [String] The relationship type ('Parent', 'Legal Guardian', etc.)
    # @return [Event] The created event record, or nil if event should be skipped
    def log_guardian_update(guardian_relationship)
      # Check if we should skip event creation because only nested attributes changed
      return nil if only_nested_attributes_changed?

      Event.create!(
        user: user,
        action: 'guardian_application_updated',
        metadata: {
          application_id: application.id,
          guardian_relationship: guardian_relationship,
          timestamp: Time.current.iso8601
        }
      )
    end

    # Create a guardian application submission event
    # @param guardian_relationship [String] The relationship type ('Parent', 'Legal Guardian', etc.)
    # @return [Event] The created event record
    def log_guardian_submission(guardian_relationship)
      Event.create!(
        user: user,
        action: 'guardian_application_submitted',
        metadata: {
          application_id: application.id,
          guardian_relationship: guardian_relationship,
          timestamp: Time.current.iso8601
        }
      )
    end

    private

    # Determines if only nested attributes (like user's guardian info) was changed
    # without any direct changes to the application itself
    def only_nested_attributes_changed?
      # If application is new, it's never "only nested attributes"
      return false if application.new_record?

      # If application record has changed, it's not "only nested attributes"
      return false if application.changed?

      # If user hasn't changed either, skip the event
      return true unless user.changed?

      # If user changed but only guardian-related fields, skip the event
      user.changed.all? { |attr| %w[is_guardian guardian_relationship].include?(attr) }
    end
  end
end
