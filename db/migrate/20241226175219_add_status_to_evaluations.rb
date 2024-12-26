class AddStatusToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :status, :integer, default: 0
  end
end
