class CreateRoleCapabilities < ActiveRecord::Migration[8.0]
  def change
    create_table :role_capabilities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :capability, null: false
      t.timestamps
    end

    add_index :role_capabilities, %i[user_id capability], unique: true
  end
end
