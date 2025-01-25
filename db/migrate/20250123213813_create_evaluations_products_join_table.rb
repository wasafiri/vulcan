class CreateEvaluationsProductsJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_join_table :evaluations, :products do |t|
      t.index :evaluation_id
      t.index :product_id
    end
  end
end
