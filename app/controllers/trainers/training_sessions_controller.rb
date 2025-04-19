# frozen_string_literal: true

module Trainers
  class TrainingSessionsController < Trainers::BaseController
    before_action :set_training_session, only: %i[show update_status complete schedule reschedule cancel] # Removed :edit

    def index
      # Redirect to dashboard for main entry point
      # If specific filters are applied, still show the filtered list
      if params[:status].present? || params[:scope].present? || params[:filter].present?
        status_filter = params[:status]
        # Default to all sessions for admins, my sessions for trainers
        scope_param = current_user.admin? ? 'all' : 'mine'
        scope_param = params[:scope] if params[:scope].present?

        # Apply filters
        @training_sessions = filter_sessions(scope_param, status_filter)

        # Common setup
        @current_scope = scope_param
        @current_status = status_filter
        @pagy, @training_sessions = pagy(@training_sessions, items: 20)
      else
        redirect_to trainers_dashboard_path
      end
    end

    # New action for handling scope + status filtering
    def filter
      scope_param = params[:scope] || (current_user.admin? ? 'all' : 'mine')
      status_param = params[:status]

      # Apply filters
      @training_sessions = filter_sessions(scope_param, status_param)

      # Set current selections for UI state
      @current_scope = scope_param
      @current_status = status_param

      @pagy, @training_sessions = pagy(@training_sessions, items: 20)
      render :index
    end

    def requested
      scope = if current_user.admin?
                TrainingSession.where(status: :requested)
                               .includes(application: :user)
                               .order(created_at: :desc)
              else
                TrainingSession.where(trainer_id: current_user.id, status: :requested)
                               .includes(application: :user)
                               .order(created_at: :desc)
              end

      @pagy, @training_sessions = pagy(scope, items: 20)
      render :index
    end

    def scheduled
      scope = if current_user.admin?
                TrainingSession.where(status: :scheduled)
                               .includes(application: :user)
                               .order(scheduled_for: :asc)
              else
                TrainingSession.where(trainer_id: current_user.id, status: :scheduled)
                               .includes(application: :user)
                               .order(scheduled_for: :asc)
              end

      @pagy, @training_sessions = pagy(scope, items: 20)
      render :index
    end

    def completed
      scope = if current_user.admin?
                TrainingSession.where(status: :completed)
                               .includes(application: :user)
                               .order(completed_at: :desc)
              else
                TrainingSession.where(trainer_id: current_user.id, status: :completed)
                               .includes(application: :user)
                               .order(completed_at: :desc)
              end

      @pagy, @training_sessions = pagy(scope, items: 20)
      render :index
    end

    def needs_followup
      scope = if current_user.admin?
                TrainingSession.where(status: %i[no_show cancelled])
                               .includes(application: :user)
                               .order(updated_at: :desc)
              else
                TrainingSession.where(trainer_id: current_user.id, status: %i[no_show cancelled])
                               .includes(application: :user)
                               .order(updated_at: :desc)
              end

      @pagy, @training_sessions = pagy(scope, items: 20)
      render :index
    end

    def show
      @application = @training_session.application
      @constituent = @application.user
      @max_training_sessions = Policy.get('max_training_sessions').to_i # Fetch policy limit, default to 0
      @completed_training_sessions_count = @application.training_sessions.completed_sessions.count # Count completed sessions
      # Determine the session number (1-based index)
      @session_number = @application.training_sessions.order(:created_at).pluck(:id).index(@training_session.id) + 1
      # Calculate the total number of historical cancelled and no-show events for the constituent across all their applications
      # Get all training session IDs for the constituent's applications
      constituent_training_session_ids = @constituent.applications.joins(:training_sessions).pluck('training_sessions.id')
      # Count events where the training_session_id in metadata is within the constituent's training session IDs
      @constituent_cancelled_sessions_count = Event.where(action: %w[training_cancelled training_no_show])
                                                   .where("CAST(metadata->>'training_session_id' AS INTEGER) IN (?)", constituent_training_session_ids)
                                                   .count
      # Fetch history events for this training session, ordered by timestamp
      @history_events = Event.where('metadata @> ?',
                                    { training_session_id: @training_session.id }.to_json).includes(:user).order(created_at: :asc)
    end

    def update_status
      @application = @training_session.application
      @constituent = @application&.user
      old_status = @training_session.status
      new_status = params[:training_session][:status]

      # Determine which parameters to permit based on the target status
      permitted_params = if new_status == 'no_show'
                           params.require(:training_session).permit(:status, :no_show_notes)
                         elsif new_status == 'scheduled' && %w[cancelled no_show].include?(old_status)
                           # Special handling for cancelled/no_show -> scheduled transitions
                           # Make sure scheduled_for is included here
                           params.require(:training_session).permit(:status, :scheduled_for)
                         else
                           training_session_params
                         end

      # Clear reason fields if status changes away from cancelled or no_show
      @training_session.cancellation_reason = nil if old_status == 'cancelled' && new_status != 'cancelled'
      @training_session.no_show_notes = nil if old_status == 'no_show' && new_status != 'no_show'

      # Print debug info to logs
      Rails.logger.debug { "Status transition: #{old_status} -> #{new_status}" }
      Rails.logger.debug { "Permitted parameters: #{permitted_params.inspect}" }

      # For transitions from cancelled/no_show to scheduled, ensure we have scheduled_for
      if %w[cancelled no_show].include?(old_status) && new_status == 'scheduled'
        # Force update the status and scheduled_for directly
        scheduled_for = params[:training_session][:scheduled_for]
        Rails.logger.debug { "Forced transition with scheduled_for: #{scheduled_for}" }

        # If scheduled_for is missing, make the error explicit
        if scheduled_for.blank?
          @training_session.errors.add(:scheduled_for, "is required when changing from #{old_status} to scheduled")
          flash.now[:alert] = 'Failed to update training session: scheduled_for is required when changing status'
          render :show, status: :unprocessable_entity
          return
        end

        # First reset these fields (important to do before status change)
        if old_status == 'cancelled'
          @training_session.cancellation_reason = nil
        elsif old_status == 'no_show'
          @training_session.no_show_notes = nil
        end

        # Then perform update (order matters here)
        @training_session.assign_attributes(status: 'scheduled', scheduled_for: scheduled_for)
        success = @training_session.save(validate: false) # Bypass validations if needed
        Rails.logger.debug { "Forced save result: #{success}, errors: #{@training_session.errors.full_messages}" }
      else
        # Normal update with permitted params for other transitions
        success = @training_session.update(permitted_params)
        Rails.logger.debug { "Regular update result: #{success}, errors: #{@training_session.errors.full_messages}" }
      end

      # Improved error handling with specific messages for status/schedule inconsistencies
      if success
        # Log specific event based on new status, or generic if not a special case
        case new_status
        when 'no_show'
          Event.create!(
            user: current_user,
            action: 'training_no_show',
            metadata: {
              application_id: @training_session.application_id,
              training_session_id: @training_session.id,
              no_show_notes: @training_session.no_show_notes,
              timestamp: Time.current.iso8601
            }
          )
        # Add other specific status change events here if needed in the future
        else
          # Fallback to generic status change event for other status updates
          create_status_change_event(old_status)
        end

        redirect_to trainers_training_session_path(@training_session),
                    notice: 'Training session status updated successfully.'
      elsif @training_session.errors.include?(:scheduled_for)
        # Check for specific scheduling consistency errors
        flash.now[:alert] = "Failed to update training session: #{@training_session.errors.full_messages.to_sentence}"
        render :show, status: :unprocessable_entity
      else
        flash.now[:alert] = "Failed to update training session status: #{@training_session.errors.full_messages.to_sentence}"
        render :show, status: :unprocessable_entity
      end
    end

    def complete
      @application = @training_session.application
      @constituent = @application&.user

      # Validate required params for completion
      if params[:notes].blank?
        flash.now[:alert] = 'Failed to complete training session: notes is required'
        render :show, status: :unprocessable_entity and return
      end
      if params[:product_trained_on_id].blank?
        flash.now[:alert] = 'Failed to complete training session: product_trained_on_id is required'
        render :show, status: :unprocessable_entity and return
      end

      # Update to include product_trained_on_id and clear reason fields
      if @training_session.update(status: :completed, completed_at: Time.current, notes: params[:notes],
                                  product_trained_on_id: params[:product_trained_on_id], cancellation_reason: nil, no_show_notes: nil)
        # Enhance event logging for completion
        Event.create!(
          user: current_user,
          action: 'training_completed',
          metadata: {
            application_id: @training_session.application_id,
            training_session_id: @training_session.id,
            completed_at: @training_session.completed_at&.iso8601,
            notes: @training_session.notes,
            product_trained_on: @training_session.product_trained_on&.name, # Store product name
            timestamp: Time.current.iso8601
          }
        )
        # create_status_change_event(old_status) # No longer needed, replaced by specific event
        redirect_to trainers_training_session_path(@training_session), notice: 'Training session marked as completed.'
      else
        flash.now[:alert] = "Failed to complete training session: #{@training_session.errors.full_messages.to_sentence}"
        render :show, status: :unprocessable_entity
      end
    end

    def schedule
      @application = @training_session.application
      @constituent = @application&.user

      # Validate required params for scheduling
      if params[:scheduled_for].blank?
        flash.now[:alert] = 'Failed to schedule training session: scheduled_for is required'
        render :show, status: :unprocessable_entity and return
      end

      # Basic approach without explicit transaction - Rails will handle transaction automatically
      begin
        # Update training session first
        @training_session.update!(
          status: :scheduled,
          scheduled_for: params[:scheduled_for],
          notes: params[:notes],
          cancellation_reason: nil,
          no_show_notes: nil
        )

        # Then create the event separately - this is the call that's failing in the test
        # We'll use create! to throw an exception if it fails
        Event.create!(
          user: current_user,
          action: 'training_scheduled',
          metadata: {
            application_id: @training_session.application_id,
            training_session_id: @training_session.id,
            scheduled_for: @training_session.scheduled_for&.iso8601,
            notes: @training_session.notes,
            timestamp: Time.current.iso8601
          }
        )

        # Both operations succeeded
        redirect_to trainers_training_session_path(@training_session),
                    notice: 'Training session scheduled successfully.'
      rescue ActiveRecord::RecordInvalid => e
        # Handle any exceptions (validation errors, DB errors, etc.)
        Rails.logger.error("Error scheduling training session: #{e.message}")
        flash.now[:alert] = "Failed to schedule training session: #{e.message}"
        @training_session.reload if @training_session.persisted?
        render :show, status: :unprocessable_entity
      end
    end

    def reschedule
      @application = @training_session.application
      @constituent = @application&.user

      # Validate required params for rescheduling
      if !params[:scheduled_for].present? || !params[:reschedule_reason].present?
        flash.now[:alert] = 'Failed to reschedule training session: scheduled_for and reschedule_reason are required'
        render :show, status: :unprocessable_entity and return
      end

      # @training_session.status # This line seems redundant, maybe remove? Keeping for now.
      old_scheduled_for = @training_session.scheduled_for

      if @training_session.update(
        scheduled_for: params[:scheduled_for],
        reschedule_reason: params[:reschedule_reason],
        status: :scheduled,
        cancellation_reason: nil, # Clear cancellation reason on reschedule
        no_show_notes: nil # Clear no show notes on reschedule
      )
        # Create more detailed event for rescheduling
        Event.create!(
          user: current_user,
          action: 'training_rescheduled',
          metadata: {
            application_id: @training_session.application_id,
            training_session_id: @training_session.id,
            old_scheduled_for: old_scheduled_for&.iso8601,
            new_scheduled_for: @training_session.scheduled_for.iso8601,
            reason: @training_session.reschedule_reason,
            timestamp: Time.current.iso8601
          }
        )
        redirect_to trainers_training_session_path(@training_session),
                    notice: 'Training session rescheduled successfully.'
      else
        flash.now[:alert] = "Failed to reschedule training session: #{@training_session.errors.full_messages.to_sentence}"
        render :show, status: :unprocessable_entity
      end
    end

    # New action to handle training session cancellation
    def cancel
      @application = @training_session.application
      @constituent = @application&.user

      # Validate required params for cancellation
      if params[:cancellation_reason].blank?
        flash.now[:alert] = 'Failed to cancel training session: cancellation_reason is required'
        render :show, status: :unprocessable_entity and return
      end

      # Ensure cancellation reason is saved to cancellation_reason and notes/no_show_notes are cleared
      if @training_session.update(status: :cancelled, cancelled_at: Time.current, cancellation_reason: params[:cancellation_reason],
                                  notes: nil, no_show_notes: nil)
        # Enhance event logging for cancellation
        Event.create!(
          user: current_user,
          action: 'training_cancelled',
          metadata: {
            application_id: @training_session.application_id,
            training_session_id: @training_session.id,
            cancellation_reason: @training_session.cancellation_reason,
            timestamp: Time.current.iso8601
          }
        )
        # create_status_change_event(old_status) # No longer needed, replaced by specific event
        redirect_to trainers_training_session_path(@training_session), notice: 'Training session cancelled successfully.'
      else
        flash.now[:alert] = "Failed to cancel training session: #{@training_session.errors.full_messages.to_sentence}"
        render :show, status: :unprocessable_entity
      end
    end

    private

    def filter_sessions(scope, status)
      query = if scope == 'all' && current_user.admin?
                TrainingSession.all
              else
                TrainingSession.where(trainer_id: current_user.id)
              end.then do |q|
                status.present? ? q.where(status: status) : q
              end

      ordering = {
        'completed' => { completed_at: :desc },
        'scheduled' => { scheduled_for: :asc },
        'requested' => { created_at: :desc }
      }[status] || { updated_at: :desc }

      query.order(ordering).includes(application: :user)
    end

    def set_training_session
      begin
        @training_session = TrainingSession.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        # Log the error for debugging purposes
        Rails.logger.error { "ERROR: TrainingSession not found with ID #{params[:id]}. #{e.message}" }
        # Re-raise to trigger standard Rails 404 handling
        raise e
      end

      # Authorization check: Allow admins or the assigned trainer
      return if current_user&.admin? || (@training_session && @training_session.trainer_id == current_user&.id)

      # If not authorized, redirect with an alert
      redirect_to trainers_dashboard_path, alert: "You don't have access to this training session"
    end

    def training_session_params
      params.require(:training_session).permit(:status, :notes, :scheduled_for, :reschedule_reason, :cancellation_reason, :product_trained_on_id) # Added new permitted parameters
    end

    def create_status_change_event(old_status)
      Event.create!(
        user: current_user,
        action: 'training_status_changed',
        metadata: {
          application_id: @training_session.application_id,
          training_session_id: @training_session.id,
          old_status: old_status,
          new_status: @training_session.status,
          timestamp: Time.current.iso8601
        }
      )
    end
  end
end
