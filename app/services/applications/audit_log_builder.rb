# frozen_string_literal: true

module Applications
  class AuditLogBuilder < BaseService
    attr_reader :application

    def initialize(application)
      super()
      @application = application
    end

    # Build combined audit logs from multiple sources
    def build_audit_logs
      return [] unless application

      [
        load_proof_reviews,
        load_status_changes,
        load_notifications,
        load_application_events,
        load_user_profile_changes
      ].flatten.sort_by(&:created_at).reverse
    rescue StandardError => e
      Rails.logger.error "Failed to build audit logs: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      add_error("Failed to build audit logs: #{e.message}")
      []
    end

    # Build deduplicated audit logs using the EventDeduplicationService
    def build_deduplicated_audit_logs
      return [] unless application

      # Collect all events from various sources
      events = build_audit_logs

      # Use the deduplication service to remove duplicates
      EventDeduplicationService.new.deduplicate(events)
    rescue StandardError => e
      Rails.logger.error "Failed to build deduplicated audit logs: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      add_error("Failed to build deduplicated audit logs: #{e.message}")
      []
    end

    private

    # Load proof reviews with minimal eager loading
    def load_proof_reviews
      ProofReview
        .select('id, application_id, admin_id, proof_type, created_at, reviewed_at, rejection_reason, notes')
        .includes(admin: []) # Include the admin but not role_capabilities
        .where(application_id: application.id)
        .order(created_at: :desc)
        .to_a
    end

    # Load status changes with minimal eager loading
    def load_status_changes
      ApplicationStatusChange
        .select('id, application_id, user_id, from_status, to_status, created_at, metadata, notes')
        .includes(user: []) # Include the user but not role_capabilities
        .where(application_id: application.id)
        .order(created_at: :desc)
        .to_a
    end

    # Load notifications with eager loading for actor association
    def load_notifications
      # For notifications, use a more optimized query and apply the decorator pattern
      # to prevent ActiveStorage eager loading on blob associations
      Notification
        .select('id, recipient_id, actor_id, notifiable_id, notifiable_type, action, read_at, created_at, message_id, delivery_status, metadata')
        .includes(:actor)
        .where(notifiable_type: 'Application', notifiable_id: application.id)
        .where(action: %w[
                 medical_certification_requested
                 medical_certification_received
                 medical_certification_approved
                 medical_certification_rejected
                 review_requested
                 documents_requested
                 proof_approved
                 proof_rejected
               ])
        .order(created_at: :desc)
        .to_a

      # Return raw notifications; decorator interferes with deduplication service type checking
    end

    # Load application events with minimal eager loading
    def load_application_events
      # For events, use a plpgsql-optimized JSONB query with minimal includes
      Event
        .select('id, user_id, action, created_at, metadata')
        .includes(:user) # Include just the user without role_capabilities
        .where(
          "action IN (?) AND (metadata->>'application_id' = ? OR metadata @> ?)",
          %w[
            voucher_assigned voucher_redeemed voucher_expired voucher_cancelled
            application_created evaluator_assigned trainer_assigned application_auto_approved
            medical_certification_requested medical_certification_status_changed # Added certification events
            alternate_contact_updated # Added to include alternate contact change events
          ],
          application.id.to_s,
          { application_id: application.id }.to_json
        )
        .order(created_at: :desc)
        .to_a
    end

    # Load user profile changes with minimal eager loading
    def load_user_profile_changes
      # Get profile changes for the application's user and any managing guardian
      user_ids = [application.user_id]
      user_ids << application.managing_guardian_id if application.managing_guardian_id.present?

      Event
        .select('id, user_id, action, created_at, metadata')
        .includes(:user)
        .where(action: %w[profile_updated profile_updated_by_guardian])
        .where(
          "(action = 'profile_updated' AND user_id IN (?)) OR (action = 'profile_updated_by_guardian' AND metadata->>'user_id' IN (?))",
          user_ids, user_ids.map(&:to_s)
        )
        .order(created_at: :desc)
        .to_a
    end
  end
end
