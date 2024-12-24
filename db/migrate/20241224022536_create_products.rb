class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.text :description
      t.decimal :price
      t.integer :quantity
      t.string :device_type
      t.datetime :archived_at
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
