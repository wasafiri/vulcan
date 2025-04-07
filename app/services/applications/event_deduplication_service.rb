# frozen_string_literal: true

module Applications
  class EventDeduplicationService < BaseService
    # Time threshold in seconds for considering events as potential duplicates
    # Events within this window will be considered for deduplication
    TIMESTAMP_THRESHOLD = 30

    # Deduplicate a collection of events from different sources
    # @param events [Array] Collection of events (Notification, ApplicationStatusChange, Event)
    # @return [Array] Deduplicated list of events
    def deduplicate(events)
      return [] if events.blank?

      events_by_key = {}

      events.each do |event|
        timestamp = extract_timestamp(event)
        timestamp_key = timestamp.strftime("%Y-%m-%d %H:%M")
        event_type = extract_event_type(event)
        provider_name = extract_provider_name(event)
        uniq_key = "#{timestamp_key}||#{event_type}||#{provider_name}"

        next if event_type.blank?

        events_by_key[uniq_key] = event if should_replace_existing_event?(events_by_key, uniq_key, event)
      end

      events_by_key.values.sort_by(&:created_at).reverse
    end

    private

    def extract_timestamp(event)
      if event.respond_to?(:metadata) && event.metadata.is_a?(Hash) && event.metadata['timestamp'].present?
        begin
          Time.parse(event.metadata['timestamp'])
        rescue StandardError
          event.created_at
        end
      else
        event.created_at
      end
    end

    def extract_event_type(event)
      case event
      when Notification, Event
        event.action
      when ApplicationStatusChange
        if event.metadata.try(:[], 'change_type') == 'medical_certification'
          "medical_certification_#{event.to_status}"
        else
          event.to_status
        end
      else
        "#{event.class.name.underscore}_#{event.id}"
      end
    end

    def extract_provider_name(event)
      if event.respond_to?(:metadata) && event.metadata.is_a?(Hash)
        event.metadata['provider_name'] || event.metadata['doctor_name']
      end
    end

    def extract_actor_name(event)
      if event.is_a?(Notification)
        event.actor&.full_name || 'System'
      elsif event.is_a?(ApplicationStatusChange) || event.is_a?(Event)
        event.user&.full_name || 'System'
      else
        'System'
      end
    end

    def should_replace_existing_event?(events_by_key, key, event)
      return true unless events_by_key.key?(key)

      existing = events_by_key[key]
      metadata_priority?(event, existing) ||
        event_type_priority?(event, existing) ||
        newer_event_priority?(event, existing)
    end

    def metadata_priority?(event, existing)
      return false unless event.respond_to?(:metadata) && existing.respond_to?(:metadata)

      event.metadata.present? && !existing.metadata.present?
    end

    def event_type_priority?(event, existing)
      (event.is_a?(ApplicationStatusChange) && !existing.is_a?(ApplicationStatusChange)) ||
        (event.is_a?(Event) && existing.is_a?(Notification))
    end

    def newer_event_priority?(event, existing)
      (event.created_at - existing.created_at) > TIMESTAMP_THRESHOLD
    end
  end
end
