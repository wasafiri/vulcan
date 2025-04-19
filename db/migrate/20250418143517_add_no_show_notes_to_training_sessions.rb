class AddNoShowNotesToTrainingSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :training_sessions, :no_show_notes, :text
  end
end
