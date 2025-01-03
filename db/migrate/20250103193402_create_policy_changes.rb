# db/migrate/[timestamp]_create_policy_changes.rb
class CreatePolicyChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :policy_changes do |t|
      t.references :policy, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :previous_value
      t.integer :new_value
      t.timestamps
    end
  end
end
