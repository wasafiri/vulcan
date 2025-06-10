# frozen_string_literal: true

# app/services/audit_event_service.rb
class AuditEventService < BaseService
  # Time window for preventing duplicate event creation.
  DEDUP_WINDOW = 5.seconds

  # Logs a distinct system event and prevents duplicates within the DEDUP_WINDOW.
  #
  # @param action [String] The specific action being performed (e.g., 'proof_approved').
  # @param actor [User] The user performing the action.
  # @param auditable [ApplicationRecord] The primary record being acted upon.
  # @param metadata [Hash] Additional context for the event.
  # @param created_at [Time] (Optional) The timestamp for the event, for testing purposes.
  # @return [Event, nil] The created Event record or nil if deduplicated.
  def self.log(action:, actor:, auditable:, metadata: {}, created_at: nil)
    # This code-level deduplication can still have race conditions under high concurrency.
    # A more robust solution would be a partial unique index in the database on
    # (action, auditable_type, auditable_id) for recent events.
    if recent_duplicate_exists?(action: action, auditable: auditable)
      Rails.logger.info "AuditEventService: Duplicate event '#{action}' for #{auditable.class.name} ##{auditable.id} suppressed."
      return nil
    end

    # Use reverse_merge to ensure caller-provided metadata is not overwritten.
    # Namespace internal keys to avoid conflicts.
    final_metadata = metadata.reverse_merge(
      __service_generated: true
    )

    event_attributes = {
      user: actor,
      action: action.to_s,
      auditable: auditable,
      metadata: final_metadata
    }

    # Only set created_at if it's provided, primarily for testing
    event_attributes[:created_at] = created_at if created_at.present?

    Event.create!(event_attributes)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "AuditEventService: Failed to log event: #{e.message}"
    raise # Re-raise the exception to make it visible in tests
  end

  # Checks if a similar event for the same record was created within the DEDUP_WINDOW.
  # A composite index on (auditable_type, auditable_id, action, created_at) is recommended for performance.
  def self.recent_duplicate_exists?(action:, auditable:)
    Event.where(action: action.to_s, auditable: auditable)
         .exists?(['created_at >= ?', DEDUP_WINDOW.ago])
  end
end
