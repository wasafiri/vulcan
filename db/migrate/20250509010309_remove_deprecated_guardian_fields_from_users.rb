class RemoveDeprecatedGuardianFieldsFromUsers < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key constraint first
    remove_foreign_key :users, column: :guardian_id, to_table: :users, if_exists: true

    # Remove index on guardian_id
    remove_index :users, :guardian_id, if_exists: true

    # Remove deprecated columns
    change_table :users, bulk: true do |t|
      t.remove :is_guardian
      t.remove :guardian_relationship
      t.remove :guardian_id
    end
  end

  def down
    # Add columns back
    change_table :users, bulk: true do |t|
      t.boolean :is_guardian, default: false
      t.string :guardian_relationship
      t.references :guardian, foreign_key: { to_table: :users }
    end
  end
end
