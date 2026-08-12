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

ActiveRecord::Schema[8.1].define(version: 2026_08_13_090000) do
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

  create_table "ai_design_requests", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "credit_cost", default: 1, null: false
    t.string "error_code"
    t.text "error_message"
    t.jsonb "metadata", default: {}, null: false
    t.text "negative_prompt"
    t.text "prompt", null: false
    t.string "provider", default: "disabled", null: false
    t.string "provider_request_id"
    t.integer "request_type", null: false
    t.bigint "requested_by_id", null: false
    t.bigint "result_design_id"
    t.bigint "shop_id", null: false
    t.bigint "source_design_id"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_request_id"], name: "index_ai_design_requests_on_provider_request", unique: true, where: "(provider_request_id IS NOT NULL)"
    t.index ["requested_by_id"], name: "index_ai_design_requests_on_requested_by_id"
    t.index ["result_design_id"], name: "index_ai_design_requests_on_result_design_id"
    t.index ["shop_id", "created_at"], name: "index_ai_design_requests_on_shop_created"
    t.index ["shop_id"], name: "index_ai_design_requests_on_shop_id"
    t.index ["source_design_id"], name: "index_ai_design_requests_on_source_design_id"
    t.check_constraint "credit_cost > 0", name: "ai_design_requests_credit_cost_positive"
    t.check_constraint "request_type >= 0 AND request_type <= 5", name: "ai_design_requests_type_range"
    t.check_constraint "status >= 0 AND status <= 5", name: "ai_design_requests_status_range"
  end

  create_table "attendance_records", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "checked_in_at", null: false
    t.datetime "checked_out_at"
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.date "work_date", null: false
    t.index ["branch_id", "work_date"], name: "index_attendance_records_on_branch_id_and_work_date"
    t.index ["branch_id"], name: "index_attendance_records_on_branch_id"
    t.index ["shop_id", "user_id", "work_date"], name: "index_attendance_on_shop_user_and_work_date", unique: true
    t.index ["shop_id", "work_date"], name: "index_attendance_records_on_shop_and_work_date"
    t.index ["shop_id"], name: "index_attendance_records_on_shop_id"
    t.index ["user_id"], name: "index_attendance_records_on_user_id"
    t.check_constraint "checked_out_at IS NULL OR checked_out_at > checked_in_at", name: "attendance_checkout_after_checkin"
  end

  create_table "branches", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "locale", default: "en", null: false
    t.string "name", null: false
    t.string "phone"
    t.bigint "shop_id", null: false
    t.string "time_zone", default: "Asia/Kolkata", null: false
    t.datetime "updated_at", null: false
    t.index ["shop_id", "code"], name: "index_branches_on_shop_id_and_code", unique: true
    t.index ["shop_id"], name: "index_branches_on_shop_id"
    t.check_constraint "code::text ~ '^[A-Z0-9_-]+$'::text", name: "branches_code_format"
    t.check_constraint "length(TRIM(BOTH FROM name)) > 0", name: "branches_name_present"
  end

  create_table "business_audit_events", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_id"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.text "reason"
    t.string "request_id"
    t.bigint "shop_id"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.index ["action", "occurred_at"], name: "index_business_audit_events_on_action_and_occurred_at"
    t.index ["actor_id"], name: "index_business_audit_events_on_actor_id"
    t.index ["auditable_type", "auditable_id"], name: "index_business_audits_on_auditable"
    t.index ["request_id"], name: "index_business_audit_events_on_request_id"
    t.index ["shop_id", "occurred_at"], name: "index_business_audit_events_on_shop_id_and_occurred_at"
    t.index ["shop_id"], name: "index_business_audit_events_on_shop_id"
  end

  create_table "customers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "address"
    t.bigint "branch_id", null: false
    t.string "city"
    t.datetime "created_at", null: false
    t.string "customer_code", null: false
    t.date "date_of_birth"
    t.string "email"
    t.string "full_name", null: false
    t.integer "gender", default: 0, null: false
    t.text "notes"
    t.string "phone_number", null: false
    t.string "preferred_language", default: "en", null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.string "whatsapp_number"
    t.index "lower((full_name)::text)", name: "index_customers_on_lower_full_name"
    t.index ["branch_id", "active", "full_name"], name: "index_customers_on_branch_id_and_active_and_full_name"
    t.index ["branch_id", "phone_number"], name: "index_customers_on_branch_id_and_phone_number", unique: true
    t.index ["branch_id"], name: "index_customers_on_branch_id"
    t.index ["shop_id", "created_at"], name: "index_customers_on_shop_and_created_at"
    t.index ["shop_id", "customer_code"], name: "index_customers_on_shop_id_and_customer_code", unique: true
    t.index ["shop_id", "phone_number"], name: "index_customers_on_shop_id_and_phone_number"
    t.index ["shop_id"], name: "index_customers_on_shop_id"
    t.check_constraint "gender >= 0 AND gender <= 3", name: "customers_gender_range"
    t.check_constraint "length(TRIM(BOTH FROM full_name)) > 0", name: "customers_name_present"
    t.check_constraint "phone_number::text ~ '^[0-9]{7,15}$'::text", name: "customers_phone_format"
    t.check_constraint "preferred_language::text = ANY (ARRAY['en'::character varying::text, 'lus'::character varying::text, 'hi'::character varying::text])", name: "customers_language"
  end

  create_table "deliveries", force: :cascade do |t|
    t.string "acknowledged_by", null: false
    t.decimal "balance_due_snapshot", precision: 12, scale: 2, null: false
    t.bigint "branch_id", null: false
    t.integer "collection_method", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.bigint "delivered_by_id", null: false
    t.string "delivery_number", null: false
    t.boolean "garment_count_verified", default: false, null: false
    t.datetime "handed_over_at", null: false
    t.text "notes"
    t.bigint "order_id", null: false
    t.boolean "packaging_complete", default: false, null: false
    t.decimal "paid_amount_snapshot", precision: 12, scale: 2, null: false
    t.boolean "payment_status_confirmed", default: false, null: false
    t.boolean "quality_checked", default: false, null: false
    t.boolean "recipient_acknowledged", default: false, null: false
    t.string "recipient_name", null: false
    t.string "recipient_phone"
    t.string "recipient_relationship"
    t.integer "sequence_number", null: false
    t.integer "sequence_year", null: false
    t.bigint "shop_id", null: false
    t.decimal "total_amount_snapshot", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "handed_over_at"], name: "index_deliveries_on_branch_id_and_handed_over_at"
    t.index ["branch_id", "sequence_year", "sequence_number"], name: "index_deliveries_on_branch_year_and_sequence", unique: true
    t.index ["branch_id"], name: "index_deliveries_on_branch_id"
    t.index ["delivered_by_id"], name: "index_deliveries_on_delivered_by_id"
    t.index ["order_id"], name: "index_deliveries_on_order_id", unique: true
    t.index ["shop_id", "delivery_number"], name: "index_deliveries_on_shop_id_and_delivery_number", unique: true
    t.index ["shop_id", "handed_over_at"], name: "index_deliveries_on_shop_and_handed_over_at"
    t.index ["shop_id"], name: "index_deliveries_on_shop_id"
    t.check_constraint "collection_method >= 0 AND collection_method <= 2", name: "deliveries_collection_method_range"
    t.check_constraint "length(TRIM(BOTH FROM recipient_name)) > 0 AND length(TRIM(BOTH FROM acknowledged_by)) > 0", name: "deliveries_recipient_present"
    t.check_constraint "quality_checked AND garment_count_verified AND payment_status_confirmed AND packaging_complete AND recipient_acknowledged", name: "deliveries_checklist_complete"
    t.check_constraint "sequence_number > 0", name: "deliveries_sequence_positive"
    t.check_constraint "sequence_year >= 2000", name: "deliveries_sequence_year"
    t.check_constraint "total_amount_snapshot >= 0::numeric AND paid_amount_snapshot >= 0::numeric AND balance_due_snapshot >= 0::numeric AND (paid_amount_snapshot + balance_due_snapshot) <= total_amount_snapshot", name: "deliveries_amounts_valid"
  end

  create_table "design_collection_items", force: :cascade do |t|
    t.bigint "added_by_id", null: false
    t.datetime "created_at", null: false
    t.bigint "design_collection_id", null: false
    t.bigint "design_id", null: false
    t.integer "position", default: 0, null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_design_collection_items_on_added_by_id"
    t.index ["design_collection_id", "design_id"], name: "index_design_collection_items_on_collection_and_design", unique: true
    t.index ["design_collection_id", "position", "id"], name: "index_design_collection_items_on_collection_position"
    t.index ["design_collection_id"], name: "index_design_collection_items_on_design_collection_id"
    t.index ["design_id"], name: "index_design_collection_items_on_design_id"
    t.index ["shop_id", "design_id"], name: "index_design_collection_items_on_shop_and_design"
    t.index ["shop_id"], name: "index_design_collection_items_on_shop_id"
    t.check_constraint "\"position\" >= 0", name: "design_collection_items_position_nonnegative"
  end

  create_table "design_collections", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "archived_at"
    t.bigint "cover_design_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.integer "design_collection_items_count", default: 0, null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.integer "visibility", default: 0, null: false
    t.index "shop_id, lower((name)::text)", name: "index_active_design_collections_on_shop_and_lower_name", unique: true, where: "active"
    t.index ["cover_design_id"], name: "index_design_collections_on_cover_design_id"
    t.index ["created_by_id"], name: "index_design_collections_on_created_by_id"
    t.index ["shop_id", "active", "position", "id"], name: "index_design_collections_on_shop_active_position"
    t.index ["shop_id", "visibility", "active", "position", "id"], name: "index_design_collections_on_shop_visibility_active_position"
    t.index ["shop_id"], name: "index_design_collections_on_shop_id"
    t.check_constraint "\"position\" >= 0", name: "design_collections_position_nonnegative"
    t.check_constraint "design_collection_items_count >= 0", name: "design_collections_count_nonnegative"
    t.check_constraint "length(TRIM(BOTH FROM name)) > 0", name: "design_collections_name_present"
    t.check_constraint "visibility >= 0 AND visibility <= 2", name: "design_collections_visibility_range"
  end

  create_table "design_favourites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "design_id", null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["design_id"], name: "index_design_favourites_on_design_id"
    t.index ["shop_id", "user_id", "design_id"], name: "index_design_favourites_on_shop_user_design", unique: true
    t.index ["shop_id"], name: "index_design_favourites_on_shop_id"
    t.index ["user_id"], name: "index_design_favourites_on_user_id"
  end

  create_table "design_selections", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.text "customer_note"
    t.bigint "design_id", null: false
    t.text "internal_note"
    t.datetime "selected_at", null: false
    t.bigint "selected_by_id", null: false
    t.bigint "shop_id", null: false
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_design_selections_on_customer_id"
    t.index ["design_id"], name: "index_design_selections_on_design_id"
    t.index ["selected_by_id"], name: "index_design_selections_on_selected_by_id"
    t.index ["shop_id", "customer_id", "archived_at", "status"], name: "index_design_selections_on_customer_gallery"
    t.index ["shop_id", "customer_id", "design_id"], name: "index_active_design_selections_unique", unique: true, where: "(archived_at IS NULL)"
    t.index ["shop_id", "customer_id", "selected_at"], name: "index_design_selections_on_shop_customer_selected"
    t.index ["shop_id", "design_id", "status"], name: "index_design_selections_on_shop_design_status"
    t.index ["shop_id"], name: "index_design_selections_on_shop_id"
    t.check_constraint "status >= 0 AND status <= 4", name: "design_selections_status_range"
  end

  create_table "design_share_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "customer_comment"
    t.integer "customer_reaction", default: 0, null: false
    t.bigint "design_id", null: false
    t.bigint "design_share_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "responded_at"
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["design_id"], name: "index_design_share_items_on_design_id"
    t.index ["design_share_id", "design_id"], name: "index_design_share_items_on_design_share_id_and_design_id", unique: true
    t.index ["design_share_id", "position", "id"], name: "index_design_share_items_on_share_position"
    t.index ["design_share_id"], name: "index_design_share_items_on_design_share_id"
    t.index ["shop_id"], name: "index_design_share_items_on_shop_id"
    t.check_constraint "\"position\" >= 0", name: "design_share_items_position_nonnegative"
    t.check_constraint "customer_reaction >= 0 AND customer_reaction <= 3", name: "design_share_items_reaction_range"
  end

  create_table "design_shares", force: :cascade do |t|
    t.boolean "allow_feedback", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "design_collection_id"
    t.datetime "expires_at", null: false
    t.text "message"
    t.datetime "revoked_at"
    t.bigint "shop_id", null: false
    t.string "title"
    t.string "token_digest", null: false
    t.string "token_hint", null: false
    t.datetime "updated_at", null: false
    t.datetime "viewed_at"
    t.index ["created_by_id"], name: "index_design_shares_on_created_by_id"
    t.index ["customer_id"], name: "index_design_shares_on_customer_id"
    t.index ["design_collection_id"], name: "index_design_shares_on_design_collection_id"
    t.index ["shop_id", "revoked_at", "expires_at"], name: "index_design_shares_on_shop_activity"
    t.index ["shop_id"], name: "index_design_shares_on_shop_id"
    t.index ["token_digest"], name: "index_design_shares_on_token_digest", unique: true
  end

  create_table "designs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "colour_family"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "design_selections_count", default: 0, null: false
    t.integer "design_share_items_count", default: 0, null: false
    t.string "embroidery_style"
    t.integer "estimated_minutes"
    t.decimal "estimated_price", precision: 12, scale: 2
    t.string "fabric_type"
    t.string "garment_type", null: false
    t.text "internal_notes"
    t.string "neck_style"
    t.string "occasion"
    t.bigint "primary_image_blob_id"
    t.datetime "rights_confirmed_at", null: false
    t.bigint "rights_confirmed_by_id", null: false
    t.bigint "shop_id", null: false
    t.string "sleeve_style"
    t.string "source_name"
    t.integer "source_type", default: 0, null: false
    t.string "source_url"
    t.string "tags", default: [], null: false, array: true
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "uploaded_by_id", null: false
    t.integer "visibility", default: 0, null: false
    t.index ["primary_image_blob_id"], name: "index_designs_on_primary_image_blob_id"
    t.index ["rights_confirmed_by_id"], name: "index_designs_on_rights_confirmed_by_id"
    t.index ["shop_id", "active", "created_at"], name: "index_designs_on_shop_id_and_active_and_created_at", order: { created_at: :desc }
    t.index ["shop_id", "garment_type", "active"], name: "index_designs_on_shop_id_and_garment_type_and_active"
    t.index ["shop_id", "visibility", "active"], name: "index_designs_on_shop_id_and_visibility_and_active"
    t.index ["shop_id"], name: "index_designs_on_shop_id"
    t.index ["tags"], name: "index_designs_on_tags", using: :gin
    t.index ["uploaded_by_id"], name: "index_designs_on_uploaded_by_id"
    t.check_constraint "design_selections_count >= 0 AND design_share_items_count >= 0", name: "designs_usage_counts_nonnegative"
    t.check_constraint "estimated_minutes IS NULL OR estimated_minutes > 0", name: "designs_estimated_minutes_positive"
    t.check_constraint "estimated_price IS NULL OR estimated_price >= 0::numeric", name: "designs_estimated_price_nonnegative"
    t.check_constraint "garment_type::text ~ '^[a-z0-9_]+$'::text", name: "designs_garment_type_format"
    t.check_constraint "length(TRIM(BOTH FROM title)) > 0", name: "designs_title_present"
    t.check_constraint "source_type >= 0 AND source_type <= 3", name: "designs_source_type_range"
    t.check_constraint "visibility >= 0 AND visibility <= 2", name: "designs_visibility_range"
  end

  create_table "expenses", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.integer "approval_status", default: 0, null: false
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.bigint "branch_id", null: false
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "description", null: false
    t.string "expense_number", null: false
    t.date "incurred_on", null: false
    t.date "next_due_on"
    t.text "notes"
    t.integer "payment_method", default: 0, null: false
    t.bigint "recorded_by_id", null: false
    t.integer "recurrence_interval", default: 0, null: false
    t.string "reference_number"
    t.integer "sequence_number", null: false
    t.integer "sequence_year", null: false
    t.bigint "shop_id", null: false
    t.bigint "source_expense_id"
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.text "void_reason"
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.index ["approved_by_id"], name: "index_expenses_on_approved_by_id"
    t.index ["branch_id", "approval_status", "voided_at"], name: "index_expenses_on_branch_id_and_approval_status_and_voided_at"
    t.index ["branch_id", "category"], name: "index_expenses_on_branch_id_and_category"
    t.index ["branch_id", "incurred_on"], name: "index_expenses_on_branch_id_and_incurred_on"
    t.index ["branch_id", "sequence_year", "sequence_number"], name: "index_expenses_on_branch_year_and_sequence", unique: true
    t.index ["branch_id"], name: "index_expenses_on_branch_id"
    t.index ["recorded_by_id"], name: "index_expenses_on_recorded_by_id"
    t.index ["shop_id", "approval_status", "voided_at", "incurred_on"], name: "index_expenses_on_shop_status_and_incurred_on"
    t.index ["shop_id", "expense_number"], name: "index_expenses_on_shop_id_and_expense_number", unique: true
    t.index ["shop_id"], name: "index_expenses_on_shop_id"
    t.index ["source_expense_id"], name: "index_expenses_on_source_expense_id"
    t.index ["voided_by_id"], name: "index_expenses_on_voided_by_id"
    t.check_constraint "amount > 0::numeric", name: "expenses_amount_positive"
    t.check_constraint "approval_status = 0 AND approved_at IS NULL AND approved_by_id IS NULL OR approval_status = 1 AND approved_at IS NOT NULL AND approved_by_id IS NOT NULL", name: "expenses_approval_consistent"
    t.check_constraint "approval_status >= 0 AND approval_status <= 1", name: "expenses_approval_status_range"
    t.check_constraint "category >= 0 AND category <= 9", name: "expenses_category_range"
    t.check_constraint "length(TRIM(BOTH FROM description)) > 0", name: "expenses_description_present"
    t.check_constraint "payment_method >= 0 AND payment_method <= 4", name: "expenses_payment_method_range"
    t.check_constraint "recurrence_interval = 0 AND next_due_on IS NULL OR recurrence_interval > 0 AND next_due_on IS NOT NULL AND next_due_on > incurred_on", name: "expenses_recurrence_consistent"
    t.check_constraint "recurrence_interval >= 0 AND recurrence_interval <= 4", name: "expenses_recurrence_range"
    t.check_constraint "sequence_number > 0", name: "expenses_sequence_positive"
    t.check_constraint "sequence_year >= 2000", name: "expenses_sequence_year"
    t.check_constraint "voided_at IS NULL AND voided_by_id IS NULL AND void_reason IS NULL OR voided_at IS NOT NULL AND voided_by_id IS NOT NULL AND length(TRIM(BOTH FROM void_reason)) > 0", name: "expenses_void_consistent"
  end

  create_table "inventory_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "branch_id", null: false
    t.integer "category", default: 0, null: false
    t.string "color"
    t.decimal "cost_price", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.decimal "quantity_on_hand", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "quantity_reserved", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "reorder_level", precision: 12, scale: 3, default: "0.0", null: false
    t.decimal "selling_price", precision: 12, scale: 2, default: "0.0", null: false
    t.bigint "shop_id", null: false
    t.string "sku", null: false
    t.string "supplier_contact"
    t.string "supplier_name"
    t.integer "unit", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_inventory_items_on_lower_name"
    t.index ["branch_id", "active", "category"], name: "index_inventory_items_on_branch_id_and_active_and_category"
    t.index ["branch_id", "sku"], name: "index_inventory_items_on_branch_id_and_sku", unique: true
    t.index ["branch_id"], name: "index_inventory_items_on_branch_id"
    t.index ["shop_id", "active", "category"], name: "index_inventory_items_on_shop_id_and_active_and_category"
    t.index ["shop_id"], name: "index_inventory_items_on_shop_id"
    t.check_constraint "category >= 0 AND category <= 7", name: "inventory_items_category_range"
    t.check_constraint "cost_price >= 0::numeric AND selling_price >= 0::numeric AND quantity_on_hand >= 0::numeric AND quantity_reserved >= 0::numeric AND reorder_level >= 0::numeric AND quantity_reserved <= quantity_on_hand", name: "inventory_items_nonnegative_values"
    t.check_constraint "length(TRIM(BOTH FROM name)) > 0", name: "inventory_items_name_present"
    t.check_constraint "sku::text ~ '^[A-Z0-9_-]+$'::text", name: "inventory_items_sku_format"
    t.check_constraint "unit >= 0 AND unit <= 6", name: "inventory_items_unit_range"
  end

  create_table "leave_requests", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.date "ends_on", null: false
    t.integer "leave_type", default: 0, null: false
    t.text "reason", null: false
    t.text "review_notes"
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.bigint "shop_id", null: false
    t.date "starts_on", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["branch_id", "status", "starts_on"], name: "index_leave_requests_on_branch_id_and_status_and_starts_on"
    t.index ["branch_id"], name: "index_leave_requests_on_branch_id"
    t.index ["reviewed_by_id"], name: "index_leave_requests_on_reviewed_by_id"
    t.index ["shop_id"], name: "index_leave_requests_on_shop_id"
    t.index ["user_id", "starts_on"], name: "index_leave_requests_on_user_id_and_starts_on"
    t.index ["user_id"], name: "index_leave_requests_on_user_id"
    t.check_constraint "(status = ANY (ARRAY[0, 3])) AND reviewed_at IS NULL AND reviewed_by_id IS NULL OR (status = ANY (ARRAY[1, 2])) AND reviewed_at IS NOT NULL AND reviewed_by_id IS NOT NULL", name: "leave_requests_review_consistent"
    t.check_constraint "ends_on >= starts_on", name: "leave_requests_dates_valid"
    t.check_constraint "leave_type >= 0 AND leave_type <= 4", name: "leave_requests_type_range"
    t.check_constraint "length(TRIM(BOTH FROM reason)) > 0", name: "leave_requests_reason_present"
    t.check_constraint "status >= 0 AND status <= 3", name: "leave_requests_status_range"
  end

  create_table "measurement_fields", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.bigint "measurement_template_id", null: false
    t.integer "position", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["measurement_template_id", "key"], name: "index_measurement_fields_on_measurement_template_id_and_key", unique: true
    t.index ["measurement_template_id", "position"], name: "idx_on_measurement_template_id_position_ab9d5c0319"
    t.index ["measurement_template_id"], name: "index_measurement_fields_on_measurement_template_id"
    t.check_constraint "\"position\" >= 0", name: "measurement_fields_position"
    t.check_constraint "key::text ~ '^[a-z][a-z0-9_]*$'::text", name: "measurement_fields_key_format"
  end

  create_table "measurement_profiles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.text "fitting_notes"
    t.bigint "measurement_template_id", null: false
    t.string "name", null: false
    t.text "posture_notes"
    t.text "preferences"
    t.bigint "shop_id", null: false
    t.string "unit", default: "inches", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "active"], name: "index_measurement_profiles_on_customer_id_and_active"
    t.index ["customer_id"], name: "index_measurement_profiles_on_customer_id"
    t.index ["measurement_template_id"], name: "index_measurement_profiles_on_measurement_template_id"
    t.index ["shop_id"], name: "index_measurement_profiles_on_shop_id"
    t.check_constraint "length(TRIM(BOTH FROM name)) > 0", name: "measurement_profiles_name_present"
    t.check_constraint "unit::text = ANY (ARRAY['inches'::character varying::text, 'centimetres'::character varying::text])", name: "measurement_profiles_unit"
  end

  create_table "measurement_templates", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "garment_type", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["garment_type"], name: "index_measurement_templates_on_garment_type", unique: true
    t.check_constraint "garment_type::text ~ '^[a-z0-9_]+$'::text", name: "measurement_templates_garment_type_format"
  end

  create_table "measurements", force: :cascade do |t|
    t.bigint "copied_from_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.date "measured_on", null: false
    t.bigint "measurement_profile_id", null: false
    t.text "notes"
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.jsonb "values", default: {}, null: false
    t.integer "version", null: false
    t.index ["copied_from_id"], name: "index_measurements_on_copied_from_id"
    t.index ["created_by_id"], name: "index_measurements_on_created_by_id"
    t.index ["measurement_profile_id", "measured_on"], name: "index_measurements_on_measurement_profile_id_and_measured_on"
    t.index ["measurement_profile_id", "version"], name: "index_measurements_on_measurement_profile_id_and_version", unique: true
    t.index ["measurement_profile_id"], name: "index_measurements_on_measurement_profile_id"
    t.index ["shop_id", "measured_on"], name: "index_measurements_on_shop_id_and_measured_on"
    t.index ["shop_id"], name: "index_measurements_on_shop_id"
    t.check_constraint "jsonb_typeof(\"values\") = 'object'::text", name: "measurements_values_object"
    t.check_constraint "version > 0", name: "measurements_version_positive"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "accepted_at"
    t.boolean "active", default: true, null: false
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.string "employee_code"
    t.string "job_title"
    t.date "joined_on"
    t.integer "pay_basis", default: 0, null: false
    t.decimal "pay_rate", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "role", default: 2, null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["branch_id"], name: "index_memberships_on_branch_id"
    t.index ["shop_id", "employee_code"], name: "index_memberships_on_shop_id_and_employee_code", unique: true, where: "(employee_code IS NOT NULL)"
    t.index ["shop_id", "role", "active"], name: "index_memberships_on_shop_id_and_role_and_active"
    t.index ["user_id", "shop_id"], name: "index_memberships_on_user_id_and_shop_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "pay_basis >= 0 AND pay_basis <= 3 AND pay_rate >= 0::numeric", name: "memberships_pay_valid"
    t.check_constraint "role >= 0 AND role <= 7", name: "memberships_role_range"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "actor_id"
    t.datetime "created_at", null: false
    t.string "message", null: false
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.integer "notification_type", null: false
    t.datetime "read_at"
    t.bigint "recipient_id", null: false
    t.bigint "shop_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["recipient_id", "notification_type", "notifiable_type", "notifiable_id"], name: "index_notifications_on_recipient_and_notifiable_and_type", unique: true
    t.index ["recipient_id", "read_at"], name: "index_notifications_on_recipient_id_and_read_at"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
    t.index ["shop_id"], name: "index_notifications_on_shop_id"
    t.check_constraint "notification_type >= 0 AND notification_type <= 2", name: "notifications_type_range"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "design_selection_id"
    t.string "garment_name", null: false
    t.bigint "measurement_id", null: false
    t.jsonb "measurement_snapshot", default: {}, null: false
    t.bigint "order_id", null: false
    t.integer "quantity", default: 1, null: false
    t.boolean "requires_embroidery", default: false, null: false
    t.bigint "shop_id", null: false
    t.text "special_instructions"
    t.decimal "unit_price", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["design_selection_id"], name: "index_order_items_on_design_selection_id"
    t.index ["measurement_id"], name: "index_order_items_on_measurement_id"
    t.index ["order_id", "id"], name: "index_order_items_on_order_id_and_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["shop_id"], name: "index_order_items_on_shop_id"
    t.check_constraint "jsonb_typeof(measurement_snapshot) = 'object'::text", name: "order_items_snapshot_object"
    t.check_constraint "length(TRIM(BOTH FROM garment_name)) > 0", name: "order_items_garment_name_present"
    t.check_constraint "quantity > 0 AND quantity <= 100", name: "order_items_quantity_range"
    t.check_constraint "unit_price >= 0::numeric", name: "order_items_unit_price_nonnegative"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "currency", default: "INR", null: false
    t.bigint "customer_id", null: false
    t.date "delivery_date", null: false
    t.decimal "discount_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.string "order_number", null: false
    t.date "ordered_on", null: false
    t.datetime "pricing_finalized_at"
    t.integer "sequence_number", null: false
    t.integer "sequence_year", null: false
    t.bigint "shop_id", null: false
    t.integer "status", default: 0, null: false
    t.decimal "subtotal_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "tax_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "tax_rate_snapshot", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "total_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.date "trial_date"
    t.datetime "updated_at", null: false
    t.index ["branch_id", "sequence_year", "sequence_number"], name: "index_orders_on_branch_year_and_sequence", unique: true
    t.index ["branch_id", "status", "delivery_date"], name: "index_orders_on_branch_id_and_status_and_delivery_date"
    t.index ["branch_id"], name: "index_orders_on_branch_id"
    t.index ["created_by_id"], name: "index_orders_on_created_by_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["shop_id", "order_number"], name: "index_orders_on_shop_id_and_order_number", unique: true
    t.index ["shop_id", "status", "delivery_date"], name: "index_orders_on_shop_id_and_status_and_delivery_date"
    t.index ["shop_id", "status", "ordered_on"], name: "index_orders_on_shop_status_and_ordered_on"
    t.index ["shop_id"], name: "index_orders_on_shop_id"
    t.check_constraint "delivery_date >= ordered_on", name: "orders_delivery_after_order"
    t.check_constraint "sequence_number > 0", name: "orders_sequence_positive"
    t.check_constraint "sequence_year >= 2000", name: "orders_sequence_year"
    t.check_constraint "status >= 0 AND status <= 3", name: "orders_status_range"
    t.check_constraint "subtotal_amount >= 0::numeric AND discount_amount >= 0::numeric AND tax_amount >= 0::numeric AND total_amount >= 0::numeric AND (pricing_finalized_at IS NULL OR discount_amount <= subtotal_amount)", name: "orders_amounts_nonnegative"
    t.check_constraint "tax_rate_snapshot >= 0::numeric AND tax_rate_snapshot <= 100::numeric", name: "orders_tax_rate_range"
    t.check_constraint "trial_date IS NULL OR trial_date >= ordered_on AND trial_date <= delivery_date", name: "orders_trial_between_dates"
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.decimal "balance_after_snapshot", precision: 12, scale: 2, null: false
    t.decimal "balance_before_snapshot", precision: 12, scale: 2, null: false
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.string "currency_snapshot", null: false
    t.text "notes"
    t.bigint "order_id", null: false
    t.decimal "order_total_snapshot", precision: 12, scale: 2, null: false
    t.date "paid_on", null: false
    t.integer "payment_method", default: 0, null: false
    t.string "payment_number", null: false
    t.bigint "received_by_id", null: false
    t.string "reference_number"
    t.integer "sequence_number", null: false
    t.integer "sequence_year", null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.text "void_reason"
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.index ["branch_id", "sequence_year", "sequence_number"], name: "index_payments_on_branch_year_and_sequence", unique: true
    t.index ["branch_id"], name: "index_payments_on_branch_id"
    t.index ["order_id", "voided_at", "paid_on"], name: "index_payments_on_order_id_and_voided_at_and_paid_on"
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["received_by_id"], name: "index_payments_on_received_by_id"
    t.index ["shop_id", "paid_on", "voided_at"], name: "index_payments_on_shop_id_and_paid_on_and_voided_at"
    t.index ["shop_id", "payment_number"], name: "index_payments_on_shop_id_and_payment_number", unique: true
    t.index ["shop_id"], name: "index_payments_on_shop_id"
    t.index ["voided_by_id"], name: "index_payments_on_voided_by_id"
    t.check_constraint "(balance_before_snapshot - amount) = balance_after_snapshot", name: "payments_snapshot_amount_matches"
    t.check_constraint "amount > 0::numeric", name: "payments_amount_positive"
    t.check_constraint "order_total_snapshot >= 0::numeric AND balance_before_snapshot >= 0::numeric AND balance_after_snapshot >= 0::numeric AND balance_after_snapshot <= balance_before_snapshot", name: "payments_snapshots_nonnegative"
    t.check_constraint "payment_method >= 0 AND payment_method <= 4", name: "payments_method_range"
    t.check_constraint "sequence_number > 0", name: "payments_sequence_positive"
    t.check_constraint "sequence_year >= 2000", name: "payments_sequence_year"
    t.check_constraint "voided_at IS NULL AND voided_by_id IS NULL AND void_reason IS NULL OR voided_at IS NOT NULL AND voided_by_id IS NOT NULL AND length(TRIM(BOTH FROM void_reason)) > 0", name: "payments_void_complete"
  end

  create_table "production_events", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "from_status"
    t.text "notes"
    t.bigint "production_task_id", null: false
    t.bigint "shop_id", null: false
    t.string "to_status"
    t.index ["actor_id"], name: "index_production_events_on_actor_id"
    t.index ["production_task_id", "created_at"], name: "index_production_events_on_production_task_id_and_created_at"
    t.index ["production_task_id"], name: "index_production_events_on_production_task_id"
    t.index ["shop_id"], name: "index_production_events_on_shop_id"
    t.check_constraint "event_type::text = ANY (ARRAY['claimed'::character varying, 'assigned'::character varying, 'started'::character varying, 'completed'::character varying, 'skipped'::character varying, 'reopened'::character varying]::text[])", name: "production_events_type"
  end

  create_table "production_tasks", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "created_at", null: false
    t.text "notes"
    t.bigint "order_item_id", null: false
    t.integer "position", null: false
    t.bigint "shop_id", null: false
    t.integer "stage", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_to_id"], name: "index_production_tasks_on_assigned_to_id"
    t.index ["completed_by_id"], name: "index_production_tasks_on_completed_by_id"
    t.index ["order_item_id", "stage"], name: "index_production_tasks_on_order_item_id_and_stage", unique: true
    t.index ["order_item_id"], name: "index_production_tasks_on_order_item_id"
    t.index ["shop_id", "status", "stage"], name: "index_production_tasks_on_shop_id_and_status_and_stage"
    t.index ["shop_id"], name: "index_production_tasks_on_shop_id"
    t.index ["status", "stage", "assigned_to_id"], name: "index_production_tasks_queue"
    t.check_constraint "(status <> ALL (ARRAY[2, 3])) OR completed_at IS NOT NULL", name: "production_tasks_completed_at"
    t.check_constraint "\"position\" >= 0", name: "production_tasks_position_positive"
    t.check_constraint "stage >= 0 AND stage <= 3", name: "production_tasks_stage_range"
    t.check_constraint "status <> 1 OR started_at IS NOT NULL", name: "production_tasks_started_at"
    t.check_constraint "status >= 0 AND status <= 3", name: "production_tasks_status_range"
  end

  create_table "shop_settings", force: :cascade do |t|
    t.text "address"
    t.bigint "branch_id", null: false
    t.jsonb "business_hours", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "INR", null: false
    t.integer "default_delivery_days", default: 14, null: false
    t.string "email"
    t.string "gpay_number"
    t.string "invoice_prefix", default: "TLR", null: false
    t.string "locale", default: "en", null: false
    t.integer "low_stock_threshold", default: 5, null: false
    t.string "measurement_unit", default: "inches", null: false
    t.string "phone"
    t.bigint "shop_id", null: false
    t.string "shop_name", null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.string "upi_id"
    t.string "whatsapp_number"
    t.index ["branch_id"], name: "index_shop_settings_on_branch_id", unique: true
    t.index ["shop_id"], name: "index_shop_settings_on_shop_id"
    t.check_constraint "default_delivery_days > 0", name: "shop_settings_delivery_days"
    t.check_constraint "gpay_number IS NULL OR gpay_number::text ~ '^[6-9][0-9]{9}$'::text", name: "shop_settings_gpay_number_format"
    t.check_constraint "low_stock_threshold >= 0", name: "shop_settings_low_stock_threshold"
    t.check_constraint "measurement_unit::text = ANY (ARRAY['inches'::character varying::text, 'centimetres'::character varying::text])", name: "shop_settings_measurement_unit"
    t.check_constraint "tax_rate >= 0::numeric AND tax_rate <= 100::numeric", name: "shop_settings_tax_rate"
    t.check_constraint "upi_id IS NULL OR length(upi_id::text) >= 5 AND length(upi_id::text) <= 100", name: "shop_settings_upi_id_length"
  end

  create_table "shops", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "country", default: "India", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.string "name", null: false
    t.datetime "onboarding_completed_at"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_shops_on_created_by_id"
    t.index ["slug"], name: "index_shops_on_slug", unique: true
    t.check_constraint "length(TRIM(BOTH FROM name)) > 0 AND length(TRIM(BOTH FROM slug)) > 0", name: "shops_identity_present"
  end

  create_table "staff_events", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.string "event_type", null: false
    t.datetime "happened_at", null: false
    t.bigint "shop_id", null: false
    t.bigint "staff_member_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_staff_events_on_actor_id"
    t.index ["branch_id", "event_type", "happened_at"], name: "index_staff_events_on_branch_id_and_event_type_and_happened_at"
    t.index ["branch_id"], name: "index_staff_events_on_branch_id"
    t.index ["shop_id"], name: "index_staff_events_on_shop_id"
    t.index ["staff_member_id", "happened_at"], name: "index_staff_events_on_staff_member_id_and_happened_at"
    t.index ["staff_member_id"], name: "index_staff_events_on_staff_member_id"
    t.check_constraint "length(TRIM(BOTH FROM event_type)) > 0", name: "staff_events_type_present"
  end

  create_table "staff_invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id", null: false
    t.datetime "revoked_at"
    t.integer "role", null: false
    t.bigint "shop_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id"], name: "index_staff_invitations_on_branch_id"
    t.index ["invited_by_id"], name: "index_staff_invitations_on_invited_by_id"
    t.index ["shop_id", "email"], name: "index_active_staff_invitations_on_shop_email", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["shop_id"], name: "index_staff_invitations_on_shop_id"
    t.index ["token_digest"], name: "index_staff_invitations_on_token_digest", unique: true
    t.check_constraint "role >= 1 AND role <= 7", name: "staff_invitations_role_range"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.date "happened_on", null: false
    t.bigint "inventory_item_id", null: false
    t.integer "movement_type", null: false
    t.text "notes"
    t.decimal "on_hand_after", precision: 12, scale: 3, null: false
    t.decimal "on_hand_before", precision: 12, scale: 3, null: false
    t.bigint "order_item_id"
    t.decimal "quantity", precision: 12, scale: 3, null: false
    t.string "reference"
    t.decimal "reserved_after", precision: 12, scale: 3, null: false
    t.decimal "reserved_before", precision: 12, scale: 3, null: false
    t.bigint "shop_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_stock_movements_on_actor_id"
    t.index ["inventory_item_id", "created_at"], name: "index_stock_movements_on_inventory_item_id_and_created_at"
    t.index ["inventory_item_id"], name: "index_stock_movements_on_inventory_item_id"
    t.index ["order_item_id", "created_at"], name: "index_stock_movements_on_order_item_id_and_created_at"
    t.index ["order_item_id"], name: "index_stock_movements_on_order_item_id"
    t.index ["shop_id", "created_at"], name: "index_stock_movements_on_shop_id_and_created_at"
    t.index ["shop_id"], name: "index_stock_movements_on_shop_id"
    t.check_constraint "movement_type >= 0 AND movement_type <= 7", name: "stock_movements_type_range"
    t.check_constraint "on_hand_before >= 0::numeric AND on_hand_after >= 0::numeric AND reserved_before >= 0::numeric AND reserved_after >= 0::numeric AND reserved_before <= on_hand_before AND reserved_after <= on_hand_after", name: "stock_movements_valid_balances"
    t.check_constraint "quantity > 0::numeric", name: "stock_movements_quantity_positive"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "emergency_contact"
    t.string "employee_code", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "job_title"
    t.date "joined_on", null: false
    t.datetime "locked_at"
    t.string "name", null: false
    t.integer "pay_basis", default: 0, null: false
    t.decimal "pay_rate", precision: 12, scale: 2, default: "0.0", null: false
    t.string "phone_number"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 2, null: false
    t.datetime "terms_accepted_at"
    t.datetime "updated_at", null: false
    t.index ["branch_id", "active", "name"], name: "index_users_on_branch_id_and_active_and_name"
    t.index ["branch_id", "role"], name: "index_users_on_branch_id_and_role"
    t.index ["branch_id"], name: "index_users_on_branch_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employee_code"], name: "index_users_on_employee_code"
    t.index ["locked_at"], name: "index_users_on_locked_at"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "employee_code::text ~ '^STF-[A-Z0-9_-]+-[0-9]{4,}$'::text", name: "users_employee_code_format"
    t.check_constraint "length(TRIM(BOTH FROM name)) > 0", name: "users_name_present"
    t.check_constraint "pay_basis >= 0 AND pay_basis <= 3", name: "users_pay_basis_range"
    t.check_constraint "pay_rate >= 0::numeric", name: "users_pay_rate_nonnegative"
    t.check_constraint "role >= 0 AND role <= 7", name: "users_role_range"
  end

  create_table "work_shifts", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.text "cancel_reason"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.datetime "ends_at", null: false
    t.string "location"
    t.text "notes"
    t.bigint "shop_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["branch_id", "starts_at"], name: "index_work_shifts_on_branch_id_and_starts_at"
    t.index ["branch_id"], name: "index_work_shifts_on_branch_id"
    t.index ["cancelled_by_id"], name: "index_work_shifts_on_cancelled_by_id"
    t.index ["created_by_id"], name: "index_work_shifts_on_created_by_id"
    t.index ["shop_id"], name: "index_work_shifts_on_shop_id"
    t.index ["user_id", "starts_at"], name: "index_work_shifts_on_user_id_and_starts_at"
    t.index ["user_id"], name: "index_work_shifts_on_user_id"
    t.check_constraint "cancelled_at IS NULL AND cancelled_by_id IS NULL AND cancel_reason IS NULL OR cancelled_at IS NOT NULL AND cancelled_by_id IS NOT NULL AND length(TRIM(BOTH FROM cancel_reason)) > 0", name: "work_shifts_cancellation_consistent"
    t.check_constraint "ends_at > starts_at", name: "work_shifts_dates_valid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_design_requests", "designs", column: "result_design_id"
  add_foreign_key "ai_design_requests", "designs", column: "source_design_id"
  add_foreign_key "ai_design_requests", "shops"
  add_foreign_key "ai_design_requests", "users", column: "requested_by_id"
  add_foreign_key "attendance_records", "branches"
  add_foreign_key "attendance_records", "shops"
  add_foreign_key "attendance_records", "users"
  add_foreign_key "branches", "shops"
  add_foreign_key "business_audit_events", "shops"
  add_foreign_key "business_audit_events", "users", column: "actor_id"
  add_foreign_key "customers", "branches"
  add_foreign_key "customers", "shops"
  add_foreign_key "deliveries", "branches"
  add_foreign_key "deliveries", "orders"
  add_foreign_key "deliveries", "shops"
  add_foreign_key "deliveries", "users", column: "delivered_by_id"
  add_foreign_key "design_collection_items", "design_collections"
  add_foreign_key "design_collection_items", "designs"
  add_foreign_key "design_collection_items", "shops"
  add_foreign_key "design_collection_items", "users", column: "added_by_id"
  add_foreign_key "design_collections", "designs", column: "cover_design_id"
  add_foreign_key "design_collections", "shops"
  add_foreign_key "design_collections", "users", column: "created_by_id"
  add_foreign_key "design_favourites", "designs"
  add_foreign_key "design_favourites", "shops"
  add_foreign_key "design_favourites", "users"
  add_foreign_key "design_selections", "customers"
  add_foreign_key "design_selections", "designs"
  add_foreign_key "design_selections", "shops"
  add_foreign_key "design_selections", "users", column: "selected_by_id"
  add_foreign_key "design_share_items", "design_shares"
  add_foreign_key "design_share_items", "designs"
  add_foreign_key "design_share_items", "shops"
  add_foreign_key "design_shares", "customers"
  add_foreign_key "design_shares", "design_collections"
  add_foreign_key "design_shares", "shops"
  add_foreign_key "design_shares", "users", column: "created_by_id"
  add_foreign_key "designs", "active_storage_blobs", column: "primary_image_blob_id"
  add_foreign_key "designs", "shops"
  add_foreign_key "designs", "users", column: "rights_confirmed_by_id"
  add_foreign_key "designs", "users", column: "uploaded_by_id"
  add_foreign_key "expenses", "branches"
  add_foreign_key "expenses", "expenses", column: "source_expense_id"
  add_foreign_key "expenses", "shops"
  add_foreign_key "expenses", "users", column: "approved_by_id"
  add_foreign_key "expenses", "users", column: "recorded_by_id"
  add_foreign_key "expenses", "users", column: "voided_by_id"
  add_foreign_key "inventory_items", "branches"
  add_foreign_key "inventory_items", "shops"
  add_foreign_key "leave_requests", "branches"
  add_foreign_key "leave_requests", "shops"
  add_foreign_key "leave_requests", "users"
  add_foreign_key "leave_requests", "users", column: "reviewed_by_id"
  add_foreign_key "measurement_fields", "measurement_templates"
  add_foreign_key "measurement_profiles", "customers"
  add_foreign_key "measurement_profiles", "measurement_templates"
  add_foreign_key "measurement_profiles", "shops"
  add_foreign_key "measurements", "measurement_profiles"
  add_foreign_key "measurements", "measurements", column: "copied_from_id"
  add_foreign_key "measurements", "shops"
  add_foreign_key "measurements", "users", column: "created_by_id"
  add_foreign_key "memberships", "branches"
  add_foreign_key "memberships", "shops"
  add_foreign_key "memberships", "users"
  add_foreign_key "notifications", "shops"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "order_items", "design_selections"
  add_foreign_key "order_items", "measurements"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "shops"
  add_foreign_key "orders", "branches"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "shops"
  add_foreign_key "orders", "users", column: "created_by_id"
  add_foreign_key "payments", "branches"
  add_foreign_key "payments", "orders"
  add_foreign_key "payments", "shops"
  add_foreign_key "payments", "users", column: "received_by_id"
  add_foreign_key "payments", "users", column: "voided_by_id"
  add_foreign_key "production_events", "production_tasks"
  add_foreign_key "production_events", "shops"
  add_foreign_key "production_events", "users", column: "actor_id"
  add_foreign_key "production_tasks", "order_items"
  add_foreign_key "production_tasks", "shops"
  add_foreign_key "production_tasks", "users", column: "assigned_to_id"
  add_foreign_key "production_tasks", "users", column: "completed_by_id"
  add_foreign_key "shop_settings", "branches"
  add_foreign_key "shop_settings", "shops"
  add_foreign_key "shops", "users", column: "created_by_id"
  add_foreign_key "staff_events", "branches"
  add_foreign_key "staff_events", "shops"
  add_foreign_key "staff_events", "users", column: "actor_id"
  add_foreign_key "staff_events", "users", column: "staff_member_id"
  add_foreign_key "staff_invitations", "branches"
  add_foreign_key "staff_invitations", "shops"
  add_foreign_key "staff_invitations", "users", column: "invited_by_id"
  add_foreign_key "stock_movements", "inventory_items"
  add_foreign_key "stock_movements", "order_items"
  add_foreign_key "stock_movements", "shops"
  add_foreign_key "stock_movements", "users", column: "actor_id"
  add_foreign_key "users", "branches"
  add_foreign_key "work_shifts", "branches"
  add_foreign_key "work_shifts", "shops"
  add_foreign_key "work_shifts", "users"
  add_foreign_key "work_shifts", "users", column: "cancelled_by_id"
  add_foreign_key "work_shifts", "users", column: "created_by_id"
end
