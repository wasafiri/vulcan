class CreateEvaluationsAccessoriesJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_join_table :evaluations, :accessories do |t|
      # t.index [:evaluation_id, :accessory_id]
      # t.index [:accessory_id, :evaluation_id]
    end
  end
end
