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

ActiveRecord::Schema[8.1].define(version: 2026_09_17_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_actions", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "admin_user_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.text "reason"
    t.bigint "subject_id", null: false
    t.string "subject_type", null: false
    t.bigint "target_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_admin_actions_on_admin_user_id"
    t.index ["created_at"], name: "index_admin_actions_on_created_at"
    t.index ["subject_type", "subject_id"], name: "index_admin_actions_on_subject_type_and_subject_id"
    t.index ["target_user_id"], name: "index_admin_actions_on_target_user_id"
  end

  create_table "legacy_nda_imports", force: :cascade do |t|
    t.string "airtable_record_id"
    t.integer "challenge_attempts", default: 0, null: false
    t.string "challenge_digest"
    t.string "challenge_email"
    t.datetime "challenge_expires_at"
    t.datetime "created_at", null: false
    t.datetime "document_purged_at"
    t.string "document_sha256"
    t.string "envelope_id"
    t.string "ip_address"
    t.bigint "nda_signature_id"
    t.jsonb "reasons", default: [], null: false
    t.string "source", default: "upload", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.jsonb "verification"
    t.index ["airtable_record_id"], name: "index_legacy_nda_imports_on_airtable_record_id"
    t.index ["created_at"], name: "index_legacy_nda_imports_on_created_at"
    t.index ["document_sha256"], name: "index_legacy_nda_imports_on_document_sha256"
    t.index ["nda_signature_id"], name: "index_legacy_nda_imports_on_nda_signature_id"
    t.index ["state"], name: "index_legacy_nda_imports_on_state"
    t.index ["user_id"], name: "index_legacy_nda_imports_on_user_id"
  end

  create_table "nda_signatures", force: :cascade do |t|
    t.string "airtable_record_id"
    t.datetime "airtable_synced_at"
    t.string "cosigner_email"
    t.datetime "cosigner_invited_at"
    t.string "cosigner_ip_address"
    t.string "cosigner_name"
    t.datetime "cosigner_reminded_at"
    t.datetime "cosigner_signed_at"
    t.string "cosigner_signed_name"
    t.string "cosigner_token_digest"
    t.datetime "cosigner_token_expires_at"
    t.text "cosigner_user_agent"
    t.datetime "created_at", null: false
    t.string "document_sha256"
    t.string "document_version", null: false
    t.datetime "identity_video_purged_at"
    t.string "ip_address"
    t.boolean "legacy_cosigner_present"
    t.datetime "legacy_cosigner_signed_at"
    t.string "legacy_document_sha256"
    t.string "legacy_envelope_id"
    t.string "legacy_signer_email"
    t.string "legacy_signer_name"
    t.string "legacy_signing_certificate_fingerprint"
    t.string "legacy_source"
    t.jsonb "legacy_verification"
    t.text "review_note"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.string "signature_type", default: "native", null: false
    t.datetime "signed_at", null: false
    t.string "signed_name", null: false
    t.text "transcript"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id", null: false
    t.decimal "validation_score", precision: 5, scale: 4
    t.string "verification_state", default: "approved", null: false
    t.index ["airtable_record_id"], name: "index_nda_signatures_on_airtable_record_id", unique: true, where: "(airtable_record_id IS NOT NULL)"
    t.index ["cosigner_token_digest"], name: "index_nda_signatures_on_cosigner_token_digest", unique: true, where: "(cosigner_token_digest IS NOT NULL)"
    t.index ["legacy_document_sha256"], name: "index_nda_signatures_on_legacy_document_sha256", unique: true, where: "(legacy_document_sha256 IS NOT NULL)"
    t.index ["legacy_envelope_id"], name: "index_nda_signatures_on_legacy_envelope_id", unique: true, where: "(legacy_envelope_id IS NOT NULL)"
    t.index ["reviewed_by_id"], name: "index_nda_signatures_on_reviewed_by_id"
    t.index ["signature_type"], name: "index_nda_signatures_on_signature_type"
    t.index ["user_id", "document_version"], name: "index_nda_signatures_on_user_id_and_document_version", unique: true
    t.index ["user_id"], name: "index_nda_signatures_on_user_id"
    t.index ["verification_state"], name: "index_nda_signatures_on_verification_state"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "address_line_1"
    t.string "address_line_2"
    t.boolean "admin", default: false, null: false
    t.datetime "airtable_checked_at"
    t.date "birthdate"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name"
    t.string "hack_club_identity_id", null: false
    t.string "last_name"
    t.string "legal_first_name"
    t.string "legal_last_name"
    t.string "postal_code"
    t.string "region"
    t.string "slack_id", null: false
    t.datetime "updated_at", null: false
    t.index ["hack_club_identity_id"], name: "index_users_on_hack_club_identity_id", unique: true
    t.index ["slack_id"], name: "index_users_on_slack_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admin_actions", "users", column: "admin_user_id"
  add_foreign_key "admin_actions", "users", column: "target_user_id"
  add_foreign_key "legacy_nda_imports", "nda_signatures"
  add_foreign_key "legacy_nda_imports", "users"
  add_foreign_key "nda_signatures", "users"
  add_foreign_key "nda_signatures", "users", column: "reviewed_by_id"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
