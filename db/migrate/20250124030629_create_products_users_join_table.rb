class CreateProductsUsersJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_join_table :products, :users do |t|
      t.index :product_id
      t.index :user_id
    end
  end
end
