# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2024_12_24_022540) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "status"
    t.integer "application_type"
    t.integer "submission_method"
    t.datetime "application_date"
    t.integer "household_size"
    t.decimal "annual_income"
    t.integer "income_verification_status"
    t.datetime "income_verified_at"
    t.bigint "income_verified_by_id", null: false
    t.text "income_details"
    t.text "residency_details"
    t.string "current_step"
    t.datetime "received_at"
    t.datetime "last_activity_at"
    t.integer "review_count"
    t.bigint "medical_provider_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["income_verified_by_id"], name: "index_applications_on_income_verified_by_id"
    t.index ["medical_provider_id"], name: "index_applications_on_medical_provider_id"
    t.index ["user_id"], name: "index_applications_on_user_id"
  end

  create_table "appointments", force: :cascade do |t|
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

  create_table "evaluations", force: :cascade do |t|
    t.bigint "evaluator_id", null: false
    t.bigint "constituent_id", null: false
    t.datetime "evaluation_date"
    t.integer "evaluation_type"
    t.boolean "report_submitted"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["constituent_id"], name: "index_evaluations_on_constituent_id"
    t.index ["evaluator_id"], name: "index_evaluations_on_evaluator_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "recipient_id", null: false
    t.bigint "actor_id", null: false
    t.string "action"
    t.datetime "read_at"
    t.jsonb "metadata"
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
  end

  create_table "policies", force: :cascade do |t|
    t.string "key"
    t.integer "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.integer "quantity"
    t.string "device_type"
    t.datetime "archived_at"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_products_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "session_token"
    t.integer "failed_attempts", default: 0
    t.index ["session_token"], name: "index_sessions_on_session_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "verified", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "type"
    t.string "first_name"
    t.string "middle_initial"
    t.string "last_name"
    t.string "phone"
    t.date "date_of_birth"
    t.string "ssn_last4"
    t.string "physical_address_1"
    t.string "physical_address_2"
    t.string "city"
    t.string "state"
    t.string "zip_code"
    t.string "county_of_residence"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts"
    t.datetime "locked_at"
    t.integer "status"
    t.boolean "valid_dcf", default: false
    t.boolean "previous_application_submitted", default: false
    t.boolean "newsletter_signup", default: false
    t.boolean "home_internet_service", default: false
    t.json "availability_schedule"
    t.integer "communication_preference"
    t.string "timezone"
    t.string "locale"
    t.string "preferred_means_of_communication"
    t.boolean "hearing_disability", default: false
    t.boolean "vision_disability", default: false
    t.boolean "speech_disability", default: false
    t.boolean "mobility_disability", default: false
    t.boolean "cognition_disability", default: false
    t.string "income_proof"
    t.string "residency_proof"
    t.bigint "income_verified_by_id"
    t.bigint "evaluator_id"
    t.bigint "recipient_id"
    t.bigint "medical_provider_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["evaluator_id"], name: "index_users_on_evaluator_id"
    t.index ["income_verified_by_id"], name: "index_users_on_income_verified_by_id"
    t.index ["medical_provider_id"], name: "index_users_on_medical_provider_id"
    t.index ["recipient_id"], name: "index_users_on_recipient_id"
    t.index ["type"], name: "index_users_on_type"
  end

  add_foreign_key "applications", "users"
  add_foreign_key "applications", "users", column: "income_verified_by_id"
  add_foreign_key "applications", "users", column: "medical_provider_id"
  add_foreign_key "appointments", "users"
  add_foreign_key "appointments", "users", column: "evaluator_id"
  add_foreign_key "evaluations", "users", column: "constituent_id"
  add_foreign_key "evaluations", "users", column: "evaluator_id"
  add_foreign_key "events", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "products", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "users", column: "evaluator_id"
  add_foreign_key "users", "users", column: "income_verified_by_id"
  add_foreign_key "users", "users", column: "medical_provider_id"
  add_foreign_key "users", "users", column: "recipient_id"
end
