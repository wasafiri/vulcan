class CreatePolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :policies do |t|
      t.string :key
      t.integer :value

      t.timestamps
    end
  end
end
