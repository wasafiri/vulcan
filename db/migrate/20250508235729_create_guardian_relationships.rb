class CreateGuardianRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :guardian_relationships do |t|
      t.references :guardian, null: false, foreign_key: { to_table: :users }
      t.references :dependent, null: false, foreign_key: { to_table: :users }
      t.string :relationship_type

      t.timestamps
    end
    add_index :guardian_relationships, %i[guardian_id dependent_id], unique: true
  end
end
