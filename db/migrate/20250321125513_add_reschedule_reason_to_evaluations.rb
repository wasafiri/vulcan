class AddRescheduleReasonToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :reschedule_reason, :text
  end
end
