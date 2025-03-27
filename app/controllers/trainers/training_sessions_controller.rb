# frozen_string_literal: true

module Trainers
  class TrainingSessionsController < Trainers::BaseController
    before_action :set_training_session, only: %i[show edit update update_status complete schedule reschedule]

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
    end

    def update_status
      old_status = @training_session.status

      # Improved error handling with specific messages for status/schedule inconsistencies
      if @training_session.update(training_session_params)
        create_status_change_event(old_status)
        redirect_to trainers_training_session_path(@training_session),
                    notice: 'Training session status updated successfully.'
      elsif @training_session.errors.include?(:scheduled_for)
        # Check for specific scheduling consistency errors
        render :show, status: :unprocessable_entity,
                      alert: "Failed to update training session: #{@training_session.errors.full_messages.to_sentence}"
      else
        render :show, status: :unprocessable_entity,
                      alert: "Failed to update training session status: #{@training_session.errors.full_messages.to_sentence}"
      end
    end

    def complete
      old_status = @training_session.status

      if @training_session.update(status: :completed, completed_at: Time.current, notes: params[:notes])
        create_status_change_event(old_status)
        redirect_to trainers_training_session_path(@training_session), notice: 'Training session marked as completed.'
      else
        render :show, status: :unprocessable_entity,
                      alert: "Failed to complete training session: #{@training_session.errors.full_messages.to_sentence}"
      end
    end

    def schedule
      old_status = @training_session.status

      if @training_session.update(status: :scheduled, scheduled_for: params[:scheduled_for])
        create_status_change_event(old_status)
        redirect_to trainers_training_session_path(@training_session),
                    notice: 'Training session scheduled successfully.'
      else
        render :show, status: :unprocessable_entity,
                      alert: "Failed to schedule training session: #{@training_session.errors.full_messages.to_sentence}"
      end
    end

    def reschedule
      @training_session.status
      old_scheduled_for = @training_session.scheduled_for

      if @training_session.update(
        scheduled_for: params[:scheduled_for],
        reschedule_reason: params[:reschedule_reason],
        status: :scheduled
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
        render :show, status: :unprocessable_entity,
                      alert: "Failed to reschedule training session: #{@training_session.errors.full_messages.to_sentence}"
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
      @training_session = TrainingSession.find(params[:id])

      # Allow admins to access any training session, but trainers can only access their own
      return if current_user.admin? || @training_session.trainer_id == current_user.id

      redirect_to trainers_dashboard_path, alert: "You don't have access to this training session"
    end

    def training_session_params
      params.require(:training_session).permit(:status, :notes, :scheduled_for, :reschedule_reason)
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
