class AddRescheduleReasonToTrainingSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :training_sessions, :reschedule_reason, :text
  end
end
