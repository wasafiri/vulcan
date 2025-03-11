class DropAppointmentsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :appointments do |t|
      t.bigint "user_id", null: false
      t.bigint "evaluator_id", null: false
      t.integer "appointment_type"
      t.datetime "scheduled_for"
      t.datetime "completed_at"
      t.text "notes"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["evaluator_id"], name: "index_appointments_on_evaluator_id"
      t.index ["user_id"], name: "index_appointments_on_user_id"
    end
  end
end
