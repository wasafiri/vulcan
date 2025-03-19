class Trainers::DashboardsController < Trainers::BaseController
  def show
    @requested_sessions = training_sessions.where(status: :requested)
                                          .order(created_at: :desc)
                                          .includes(application: :user)
                                          .limit(10)
    @scheduled_sessions = training_sessions.where(status: :scheduled)
    @completed_sessions = training_sessions.where(status: :completed).limit(5)
    @followup_sessions = training_sessions.where(status: [:no_show, :cancelled]).limit(5)
    
    # Get upcoming training sessions for the next 7 days
    @upcoming_sessions = @scheduled_sessions.where(scheduled_for: Time.current..7.days.from_now)
                                           .order(scheduled_for: :asc)
                                           .includes(application: :user)
                                           .limit(10)

    # Get count for any training sessions assigned to this user
    # For admins, always use their own trainer_id for this count to ensure consistency
    @my_training_requests_count = TrainingSession.where(trainer_id: current_user.id, 
                                                       status: [:requested, :scheduled, :confirmed]).count
  end

  private

  def training_sessions
    @training_sessions ||= if current_user.admin?
                            # Show all training sessions for admins
                            TrainingSession.all.includes(application: :user)
                          else
                            # Show only the trainer's own sessions for trainers
                            TrainingSession.where(trainer_id: current_user.id)
                                          .includes(application: :user)
                          end
  end
end
