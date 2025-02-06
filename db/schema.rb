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

ActiveRecord::Schema[8.0].define(version: 2025_02_06_043412) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accessories_evaluations", id: false, force: :cascade do |t|
    t.bigint "evaluation_id", null: false
    t.bigint "accessory_id", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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
    t.bigint "income_verified_by_id"
    t.text "income_details"
    t.text "residency_details"
    t.string "current_step"
    t.datetime "received_at"
    t.datetime "last_activity_at"
    t.integer "review_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "self_certify_disability", default: false
    t.boolean "maryland_resident"
    t.boolean "terms_accepted"
    t.boolean "information_verified"
    t.boolean "medical_release_authorized"
    t.integer "income_proof_status", default: 0, null: false
    t.integer "residency_proof_status", default: 0, null: false
    t.string "medical_provider_name"
    t.string "medical_provider_phone"
    t.string "medical_provider_fax"
    t.string "medical_provider_email"
    t.integer "total_rejections", default: 0, null: false
    t.datetime "last_proof_submitted_at"
    t.datetime "needs_review_since"
    t.bigint "trainer_id"
    t.integer "medical_certification_status", default: 0, null: false
    t.datetime "medical_certification_verified_at"
    t.bigint "medical_certification_verified_by_id"
    t.text "medical_certification_rejection_reason"
    t.index ["income_verified_by_id"], name: "index_applications_on_income_verified_by_id"
    t.index ["last_proof_submitted_at"], name: "index_applications_on_last_proof_submitted_at"
    t.index ["medical_certification_status"], name: "index_applications_on_medical_certification_status"
    t.index ["medical_certification_verified_by_id"], name: "index_applications_on_medical_certification_verified_by_id"
    t.index ["medical_provider_email", "status"], name: "index_applications_on_medical_provider_email_and_status"
    t.index ["needs_review_since"], name: "index_applications_on_needs_review_since"
    t.index ["status", "needs_review_since"], name: "index_applications_on_status_and_needs_review_since"
    t.index ["total_rejections"], name: "index_applications_on_total_rejections"
    t.index ["trainer_id"], name: "index_applications_on_trainer_id"
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

  create_table "email_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "subject"
    t.text "body"
    t.text "variables", default: [], array: true
    t.bigint "updated_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_email_templates_on_name", unique: true
    t.index ["updated_by_id"], name: "index_email_templates_on_updated_by_id"
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
    t.integer "status", default: 0
    t.bigint "application_id", null: false
    t.text "needs"
    t.integer "recommended_product_ids", default: [], array: true
    t.datetime "evaluation_datetime"
    t.string "location"
    t.jsonb "attendees", default: []
    t.jsonb "products_tried", default: []
    t.index ["application_id"], name: "index_evaluations_on_application_id"
    t.index ["constituent_id"], name: "index_evaluations_on_constituent_id"
    t.index ["evaluator_id"], name: "index_evaluations_on_evaluator_id"
  end

  create_table "evaluations_products", id: false, force: :cascade do |t|
    t.bigint "evaluation_id", null: false
    t.bigint "product_id", null: false
  end

  create_table "events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.index ["metadata"], name: "index_events_on_metadata", using: :gin
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

  create_table "policy_changes", force: :cascade do |t|
    t.bigint "policy_id", null: false
    t.bigint "user_id", null: false
    t.integer "previous_value"
    t.integer "new_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_id"], name: "index_policy_changes_on_policy_id"
    t.index ["user_id"], name: "index_policy_changes_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.decimal "price"
    t.integer "quantity"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "manufacturer"
    t.string "model_number"
    t.text "features"
    t.text "compatibility_notes"
    t.string "documentation_url"
    t.string "device_types", default: [], array: true
    t.index ["device_types"], name: "index_products_on_device_types", using: :gin
  end

  create_table "products_users", id: false, force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "user_id", null: false
    t.index ["product_id"], name: "index_products_users_on_product_id"
    t.index ["user_id"], name: "index_products_users_on_user_id"
  end

  create_table "proof_reviews", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "admin_id", null: false
    t.string "proof_type", null: false
    t.string "status", null: false
    t.text "rejection_reason"
    t.string "submission_method"
    t.datetime "reviewed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id", "created_at"], name: "index_proof_reviews_on_admin_id_and_created_at"
    t.index ["admin_id"], name: "index_proof_reviews_on_admin_id"
    t.index ["application_id", "proof_type", "created_at"], name: "idx_on_application_id_proof_type_created_at_4b8ffa7c5f"
    t.index ["application_id"], name: "index_proof_reviews_on_application_id"
    t.index ["status"], name: "index_proof_reviews_on_status"
  end

  create_table "role_capabilities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "capability", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "capability"], name: "index_role_capabilities_on_user_id_and_capability", unique: true
    t.index ["user_id"], name: "index_role_capabilities_on_user_id"
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

  create_table "solid_queue_tables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "training_sessions", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "trainer_id", null: false
    t.datetime "scheduled_for"
    t.datetime "completed_at"
    t.integer "status", default: 0
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_training_sessions_on_application_id"
    t.index ["trainer_id"], name: "index_training_sessions_on_trainer_id"
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
    t.bigint "income_verified_by_id"
    t.bigint "evaluator_id"
    t.bigint "recipient_id"
    t.bigint "medical_provider_id"
    t.boolean "email_verified"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "is_guardian", default: false
    t.string "guardian_relationship"
    t.bigint "guardian_id"
    t.string "fax"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["evaluator_id"], name: "index_users_on_evaluator_id"
    t.index ["guardian_id"], name: "index_users_on_guardian_id"
    t.index ["income_verified_by_id"], name: "index_users_on_income_verified_by_id"
    t.index ["medical_provider_id"], name: "index_users_on_medical_provider_id"
    t.index ["recipient_id"], name: "index_users_on_recipient_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["type"], name: "index_users_on_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "applications", "users"
  add_foreign_key "applications", "users", column: "income_verified_by_id"
  add_foreign_key "applications", "users", column: "medical_certification_verified_by_id"
  add_foreign_key "applications", "users", column: "trainer_id"
  add_foreign_key "appointments", "users"
  add_foreign_key "appointments", "users", column: "evaluator_id"
  add_foreign_key "email_templates", "users", column: "updated_by_id"
  add_foreign_key "evaluations", "applications"
  add_foreign_key "evaluations", "users", column: "constituent_id"
  add_foreign_key "evaluations", "users", column: "evaluator_id"
  add_foreign_key "events", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "policy_changes", "policies"
  add_foreign_key "policy_changes", "users"
  add_foreign_key "proof_reviews", "applications"
  add_foreign_key "proof_reviews", "users", column: "admin_id"
  add_foreign_key "role_capabilities", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "training_sessions", "applications"
  add_foreign_key "training_sessions", "users", column: "trainer_id"
  add_foreign_key "users", "users", column: "evaluator_id"
  add_foreign_key "users", "users", column: "guardian_id"
  add_foreign_key "users", "users", column: "income_verified_by_id"
  add_foreign_key "users", "users", column: "medical_provider_id"
  add_foreign_key "users", "users", column: "recipient_id"
end
