class AddLastVisitedStepToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :last_visited_step, :string
  end
end
