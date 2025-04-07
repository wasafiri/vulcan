# frozen_string_literal: true

module Applications
  # Service for handling certification-related event processing
  # Centralizes certification event filtering, deduplication, and formatting
  # for consistent display across different views
  class CertificationEventsService
    def initialize(application)
      @application = application
      @audit_log_builder = AuditLogBuilder.new(application)
    end

    # Return basic certification events (already deduplicated)
    def certification_events
      # Start with deduplicated logs for efficiency
      deduplicated_logs = @audit_log_builder.build_deduplicated_audit_logs

      # Filter for certification-related events
      deduplicated_logs.select do |event|
        (event.is_a?(Notification) && event.action.to_s.include?("certification")) ||
        (event.is_a?(ApplicationStatusChange) && 
         (event.metadata.try(:[], 'change_type') == 'medical_certification' || 
          event.from_status.to_s.include?('certification') || 
          event.to_status.to_s.include?('certification'))) ||
        (event.is_a?(Event) && 
         (event.action.to_s.include?('certification') || 
          (event.metadata.is_a?(Hash) && event.metadata.to_s.include?('certification'))))
      end
    end

    # Return request events identified and processed for display
    def request_events
      events = certification_events

      # Identify which are request events
      request_events = events.select do |event|
        (event.is_a?(Notification) && event.action == "medical_certification_requested") ||
        (event.is_a?(ApplicationStatusChange) && event.to_status == "requested") ||
        (event.is_a?(Event) && (event.action == "medical_certification_requested" ||
                               (event.metadata.is_a?(Hash) &&
                                event.metadata['details'].to_s.include?('certification requested')))) ||
        (event.respond_to?(:metadata) &&
         event.metadata.is_a?(Hash) &&
         event.metadata.to_s.include?('certification requested'))
      end

      # Process these events for display
      process_request_events_for_display(request_events)
    end

    private

    def process_request_events_for_display(events)
      unique_requests = {}

      events.each do |event|
        timestamp = determine_timestamp(event)
        timestamp_key = timestamp.strftime("%Y-%m-%d %H:%M")
        actor_name = determine_actor_name(event)
        submission_method = determine_submission_method(event)

        if !unique_requests.key?(timestamp_key) ||
           (submission_method.present? && unique_requests[timestamp_key][:submission_method].blank?)
          unique_requests[timestamp_key] = {
            timestamp: timestamp,
            actor_name: actor_name,
            submission_method: submission_method
          }
        end
      end
      unique_requests.values.sort_by { |r| r[:timestamp] }.reverse
    end

    def determine_timestamp(event)
      timestamp = event.created_at
      if event.respond_to?(:metadata) && event.metadata.is_a?(Hash) && event.metadata['timestamp'].present?
        begin
          timestamp = Time.zone.parse(event.metadata['timestamp'])
        rescue StandardError
        # fall back to the original timestamp if parsing fails
        end
      end
      timestamp
    end

    def determine_actor_name(event)
      if event.is_a?(Notification)
        event.actor&.full_name || 'System'
      elsif event.is_a?(ApplicationStatusChange) || event.is_a?(Event)
        event.user&.full_name || 'System'
      else
        'System'
      end
    end

    def determine_submission_method(event)
      return unless event.respond_to?(:metadata) && event.metadata.is_a?(Hash)

      event.metadata['submission_method'] || event.metadata['method'] || event.metadata['delivery_method']
    end
  end
end
