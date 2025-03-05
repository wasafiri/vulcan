class CreateJoinTableApplicationsProducts < ActiveRecord::Migration[8.0]
  def change
    create_join_table :applications, :products do |t|
      t.index [ :application_id, :product_id ]
      t.index [ :product_id, :application_id ]
    end
  end
end
