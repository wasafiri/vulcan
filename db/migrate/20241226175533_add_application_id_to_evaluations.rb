class AddApplicationIdToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_reference :evaluations, :application, null: false, foreign_key: true
  end
end
