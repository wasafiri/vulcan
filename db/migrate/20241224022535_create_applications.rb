class CreateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :applications do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status
      t.integer :application_type
      t.integer :submission_method
      t.datetime :application_date
      t.integer :household_size
      t.decimal :annual_income
      t.datetime :income_verified_at
      t.references :income_verified_by, foreign_key: { to_table: :users }
      t.text :income_details
      t.text :residency_details
      t.string :current_step
      t.datetime :received_at
      t.datetime :last_activity_at
      t.integer :review_count
      t.references :medical_provider, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
