class CreateW9Reviews < ActiveRecord::Migration[8.0]
  def change
    create_table :w9_reviews do |t|
      t.references :vendor, null: false, foreign_key: { to_table: :users }
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.integer :rejection_reason_code
      t.text :rejection_reason
      t.datetime :reviewed_at, null: false

      t.timestamps
    end
  end
end
