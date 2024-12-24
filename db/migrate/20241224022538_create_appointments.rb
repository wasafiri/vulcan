class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :evaluator, null: false, foreign_key: { to_table: :users }
      t.integer :appointment_type
      t.datetime :scheduled_for
      t.datetime :completed_at
      t.text :notes

      t.timestamps
    end
  end
end
