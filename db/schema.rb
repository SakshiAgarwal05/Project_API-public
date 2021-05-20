# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20210331104924) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "citext"
  enable_extension "fuzzystrmatch"
  enable_extension "pg_stat_statements"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

  create_table "_yoyo_migration", id: :string, limit: 255, force: :cascade do |t|
    t.datetime "ctime"
  end

  create_table "accessibles", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "agency_id"
    t.uuid "client_id"
    t.uuid "hiring_organization_id"
    t.uuid "billing_term_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "created_by_id"
    t.boolean "incumbent"
    t.index ["agency_id"], name: "index_accessibles_on_agency_id"
    t.index ["billing_term_id"], name: "index_accessibles_on_billing_term_id"
    t.index ["client_id"], name: "index_accessibles_on_client_id"
    t.index ["created_by_id"], name: "index_accessibles_on_created_by_id"
    t.index ["hiring_organization_id"], name: "index_accessibles_on_hiring_organization_id"
  end

  create_table "acknowledge_disqualified_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "talents_job_id"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["talents_job_id"], name: "index_acknowledge_disqualified_users_on_talents_job_id"
    t.index ["user_id"], name: "index_acknowledge_disqualified_users_on_user_id"
  end

  create_table "acknowledge_job_hold_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "job_id"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_acknowledge_job_hold_users_on_job_id"
    t.index ["user_id"], name: "index_acknowledge_job_hold_users_on_user_id"
  end

  create_table "affiliates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "type"
    t.uuid "user_id"
    t.uuid "agency_id"
    t.uuid "job_id"
    t.integer "status_int"
    t.string "ref_int"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "created_by_id"
    t.integer "viewed_count"
    t.string "dismissed_reason"
    t.string "status"
    t.string "ref"
    t.boolean "responded", default: false
    t.string "type_of_distribution", default: "system"
    t.string "email_status"
    t.string "saved_from"
    t.jsonb "status_change_history", default: {}
    t.index ["type", "user_id", "job_id", "status", "responded"], name: "affiliates_index"
  end

  create_table "agencies", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.string "company_name"
    t.boolean "enabled", default: true
    t.text "logo"
    t.boolean "image_resized", default: false
    t.boolean "if_valid", default: false
    t.text "summary"
    t.string "job_types", default: [], array: true
    t.uuid "timezone_id"
    t.uuid "created_by_id"
    t.uuid "updated_by_id"
    t.string "website"
    t.string "login_url"
    t.boolean "restrict_access", default: false
    t.string "contact_number"
    t.string "expertise_category1"
    t.string "expertise_category2"
    t.string "expertise_category3"
    t.string "initials"
    t.string "logo_100_public"
    t.string "logo_50_public"
    t.datetime "locked_at"
    t.datetime "verified_at"
    t.index ["deleted_at", "created_by_id"], name: "index_agencies_on_created_by_id"
    t.index ["deleted_at", "timezone_id"], name: "index_agencies_on_timezone_id"
    t.index ["deleted_at", "updated_by_id"], name: "index_agencies_on_updated_by_id"
    t.index ["id", "deleted_at"], name: "index_agencies_on_id_and_deleted_at"
    t.index ["login_url"], name: "index_agencies_on_login_url", unique: true
  end

  create_table "agencies_billing_terms", id: false, force: :cascade do |t|
    t.uuid "agency_id", null: false
    t.uuid "billing_term_id", null: false
    t.index ["agency_id", "billing_term_id"], name: "index_agencies_billing_terms_on_agency_id_and_billing_term_id"
  end

  create_table "agencies_clients", id: false, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.uuid "agency_id", null: false
    t.index ["agency_id"], name: "index_agencies_clients_on_agency_id"
    t.index ["client_id", "agency_id"], name: "index_agencies_clients_on_client_id_and_agency_id"
  end

  create_table "agencies_jobs", id: false, force: :cascade do |t|
    t.uuid "job_id"
    t.uuid "agency_id"
    t.index ["agency_id"], name: "index_agencies_jobs_on_agency_id"
    t.index ["job_id", "agency_id"], name: "index_agencies_jobs_on_job_id_and_agency_id"
  end

  create_table "assignables", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "agency_id"
    t.uuid "client_id"
    t.boolean "is_primary"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "assignment_details", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float "salary"
    t.date "start_date"
    t.string "pay_period"
    t.date "end_date"
    t.float "hours_per_week", default: 37.5
    t.datetime "shift_start"
    t.datetime "shift_length"
    t.boolean "possibility_of_extension", default: false
    t.uuid "updated_by_id"
    t.uuid "completed_transition_id"
    t.uuid "talents_job_id"
    t.string "location"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.string "duration"
    t.string "duration_period"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.boolean "overtime", default: false
    t.string "start_time"
    t.string "end_time"
    t.uuid "timezone_id"
    t.string "primary_end_reason"
    t.string "secondary_end_reason"
    t.index ["completed_transition_id", "end_date", "id", "updated_at"], name: "ass_det_ct_end_date_id_updated"
    t.index ["talents_job_id"], name: "index_assignment_details_on_talents_job_id"
    t.index ["timezone_id"], name: "index_assignment_details_on_timezone_id"
    t.index ["updated_by_id"], name: "index_assignment_details_on_updated_by_id"
  end

  create_table "ats_platforms", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
  end

  create_table "background_job_loggers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "job_name"
    t.jsonb "parameters"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "badges", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "badge_label"
    t.uuid "job_id"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id", "user_id"], name: "index_badges_on_job_id_and_user_id"
    t.index ["job_id"], name: "index_badges_on_job_id"
    t.index ["user_id"], name: "index_badges_on_user_id"
  end

  create_table "bcc_messages_talents", id: false, force: :cascade do |t|
    t.uuid "talent_id"
    t.uuid "message_id"
    t.index ["message_id", "talent_id"], name: "index_bcc_messages_talents_on_message_id_and_talent_id"
    t.index ["message_id"], name: "index_bcc_messages_talents_on_message_id"
    t.index ["talent_id"], name: "index_bcc_messages_talents_on_talent_id"
  end

  create_table "bcc_messages_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "message_id"
    t.index ["message_id", "user_id"], name: "index_bcc_messages_users_on_message_id_and_user_id"
    t.index ["message_id"], name: "index_bcc_messages_users_on_message_id"
    t.index ["user_id"], name: "index_bcc_messages_users_on_user_id"
  end

  create_table "benefits", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.boolean "is_enable", default: true
    t.boolean "is_restricted", default: true
  end

  create_table "benefits_categories", id: false, force: :cascade do |t|
    t.uuid "benefit_id", null: false
    t.uuid "category_id", null: false
    t.index ["benefit_id", "category_id"], name: "index_benefits_categories_on_benefit_id_and_category_id"
  end

  create_table "benefits_locations", id: false, force: :cascade do |t|
    t.uuid "benefit_id", null: false
    t.uuid "location_id", null: false
    t.index ["benefit_id"], name: "index_benefits_locations_on_benefit_id"
    t.index ["location_id"], name: "index_benefits_locations_on_location_id"
  end

  create_table "bill_rate_negotiations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "status", default: "requested"
    t.text "proposed_note"
    t.float "value"
    t.uuid "rtr_id"
    t.uuid "proposed_by_id"
    t.uuid "approved_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "approve_note"
    t.text "reject_note"
    t.uuid "rejected_by_id"
    t.uuid "proposed_bill_rate_id"
    t.boolean "if_declined_and_proposed", default: false
    t.float "last_bill_rate"
    t.index ["approved_by_id"], name: "index_bill_rate_negotiations_on_approved_by_id"
    t.index ["proposed_bill_rate_id"], name: "index_bill_rate_negotiations_on_proposed_bill_rate_id"
    t.index ["proposed_by_id"], name: "index_bill_rate_negotiations_on_proposed_by_id"
    t.index ["rejected_by_id"], name: "index_bill_rate_negotiations_on_rejected_by_id"
    t.index ["rtr_id"], name: "index_bill_rate_negotiations_on_rtr_id"
  end

  create_table "billing_terms", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "billing_name"
    t.string "type_of_job"
    t.string "currency"
    t.string "pay_period"
    t.string "platform_type"
    t.string "msp_notes"
    t.integer "guarantee_period"
    t.integer "exclusivity_period"
    t.integer "billing_type"
    t.float "msp_vms_fee_rate"
    t.float "crowdstaffing_margin"
    t.jsonb "agency_placement_fee"
    t.jsonb "placement_fee"
    t.jsonb "bill_markup"
    t.jsonb "currency_obj"
    t.boolean "enable", default: true
    t.boolean "msp_available"
    t.boolean "crowdstaffing_payroll"
    t.boolean "update_vms_for_job", default: false
    t.uuid "client_id"
    t.uuid "msp_name_id"
    t.uuid "ats_platform_id"
    t.uuid "vms_platform_id"
    t.uuid "proprietary_platform_id"
    t.uuid "created_by_id"
    t.uuid "hiring_organization_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "exclusive_access_time"
    t.string "exclusive_access_period"
    t.boolean "is_exclusive", default: false
    t.datetime "locked_at"
    t.index ["deleted_at", "ats_platform_id"], name: "index_billing_terms_on_ats_platform_id"
    t.index ["deleted_at", "client_id"], name: "index_billing_terms_on_client_id"
    t.index ["deleted_at", "created_by_id"], name: "index_billing_terms_on_created_by_id"
    t.index ["deleted_at", "hiring_organization_id"], name: "index_billing_terms_on_hiring_organization_id"
    t.index ["deleted_at", "msp_name_id"], name: "index_billing_terms_on_msp_name_id"
    t.index ["deleted_at", "proprietary_platform_id"], name: "index_billing_terms_on_proprietary_platform_id"
    t.index ["deleted_at", "vms_platform_id"], name: "index_billing_terms_on_vms_platform_id"
    t.index ["id", "deleted_at"], name: "index_billing_terms_on_id_and_deleted_at"
  end

  create_table "billing_terms_categories", id: false, force: :cascade do |t|
    t.uuid "billing_term_id", null: false
    t.uuid "category_id", null: false
    t.index ["billing_term_id"], name: "index_billing_terms_categories_on_billing_term_id"
    t.index ["category_id"], name: "index_billing_terms_categories_on_category_id"
  end

  create_table "billing_terms_countries", id: false, force: :cascade do |t|
    t.uuid "billing_term_id", null: false
    t.uuid "country_id", null: false
    t.index ["billing_term_id"], name: "index_billing_terms_countries_on_billing_term_id"
    t.index ["country_id"], name: "index_billing_terms_countries_on_country_id"
  end

  create_table "billing_terms_states", id: false, force: :cascade do |t|
    t.uuid "billing_term_id", null: false
    t.uuid "state_id", null: false
    t.index ["billing_term_id"], name: "index_billing_terms_states_on_billing_term_id"
    t.index ["state_id"], name: "index_billing_terms_states_on_state_id"
  end

  create_table "categories", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.index ["id", "name"], name: "index_categories_on_id_and_name"
  end

  create_table "categories_clients", id: false, force: :cascade do |t|
    t.uuid "category_id", null: false
    t.uuid "client_id", null: false
    t.index ["category_id"], name: "index_categories_clients_on_category_id"
    t.index ["client_id"], name: "index_categories_clients_on_client_id"
  end

  create_table "categories_contacts", id: false, force: :cascade do |t|
    t.uuid "category_id", null: false
    t.uuid "contact_id", null: false
    t.index ["category_id"], name: "index_categories_contacts_on_category_id"
    t.index ["contact_id"], name: "index_categories_contacts_on_contact_id"
  end

  create_table "categories_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "category_id"
    t.index ["category_id", "user_id"], name: "index_categories_users_on_category_id_and_user_id"
  end

  create_table "cc_messages_talents", id: false, force: :cascade do |t|
    t.uuid "talent_id"
    t.uuid "message_id"
    t.index ["message_id", "talent_id"], name: "index_cc_messages_talents_on_message_id_and_talent_id"
    t.index ["message_id"], name: "index_cc_messages_talents_on_message_id"
    t.index ["talent_id"], name: "index_cc_messages_talents_on_talent_id"
  end

  create_table "cc_messages_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "message_id"
    t.index ["message_id", "user_id"], name: "index_cc_messages_users_on_message_id_and_user_id"
    t.index ["message_id"], name: "index_cc_messages_users_on_message_id"
    t.index ["user_id"], name: "index_cc_messages_users_on_user_id"
  end

  create_table "certificates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "name"
    t.uuid "vendor_id"
    t.index ["vendor_id"], name: "index_certificates_on_vendor_id"
  end

  create_table "certifications", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "certificate_id"
    t.date "start_date"
    t.uuid "vendor_id"
    t.uuid "embeddable_id"
    t.string "embeddable_type"
    t.index ["certificate_id"], name: "index_certifications_on_certificate_id"
    t.index ["embeddable_type", "embeddable_id"], name: "index_certificates_on_embeddable"
    t.index ["vendor_id"], name: "index_certifications_on_vendor_id"
  end

  create_table "change_histories", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "entity_type"
    t.uuid "entity_id"
    t.string "column_name"
    t.string "current_value"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_updated_at"
    t.index ["entity_id"], name: "index_change_histories_on_entity_id"
    t.index ["user_id"], name: "index_change_histories_on_user_id"
  end

  create_table "cities", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "abbr"
    t.string "name"
    t.string "postal_code"
    t.string "coordinate"
    t.uuid "state_id"
    t.index ["state_id"], name: "index_cities_on_state_id"
  end

  create_table "clients", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "company_name"
    t.string "company_size"
    t.string "founded"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.string "website"
    t.text "logo"
    t.boolean "image_resized", default: false
    t.text "about"
    t.integer "jobs_count", default: 0
    t.boolean "active", default: true
    t.string "status"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.boolean "is_private", default: false
    t.string "benefits", default: [], array: true
    t.string "industry_name"
    t.uuid "timezone_id"
    t.uuid "industry_id"
    t.uuid "created_by_id"
    t.uuid "resume_template_id"
    t.string "initials"
    t.string "logo_100_public"
    t.string "logo_50_public"
    t.string "logo_banner"
    t.index ["company_name", "deleted_at"], name: "index_clients_on_company_name_and_deleted_at"
    t.index ["deleted_at", "created_by_id"], name: "index_clients_on_created_by_id"
    t.index ["deleted_at", "id", "company_name"], name: "index_clients_on_deleted_at_and_id_and_company_name"
    t.index ["deleted_at", "industry_id"], name: "index_clients_on_industry_id"
    t.index ["deleted_at", "resume_template_id"], name: "index_clients_on_resume_template_id"
    t.index ["deleted_at", "timezone_id"], name: "index_clients_on_timezone_id"
    t.index ["id", "deleted_at"], name: "index_clients_on_id_and_deleted_at"
  end

  create_table "companies", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.integer "popularity", default: 0
  end

  create_table "completed_transitions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "stage"
    t.text "note"
    t.string "subject"
    t.text "body"
    t.string "tag"
    t.string "tag_note"
    t.boolean "current", default: true
    t.string "updated_by_type"
    t.uuid "updated_by_id"
    t.uuid "event_id"
    t.uuid "talents_job_id"
    t.uuid "pipeline_step_id"
    t.string "email"
    t.boolean "spoken_to_candidate", default: false
    t.index ["deleted_at", "event_id"], name: "index_completed_transitions_on_event_id"
    t.index ["deleted_at", "pipeline_step_id"], name: "index_completed_transitions_on_pipeline_step_id"
    t.index ["deleted_at", "stage", "talents_job_id", "id", "created_at", "updated_at"], name: "ct_stage_talent_job_id_created_updated"
    t.index ["deleted_at", "talents_job_id", "stage"], name: "index_ct_on_tj_and_stage"
    t.index ["deleted_at", "updated_by_id", "updated_by_type"], name: "completed_transitions_updated_by"
  end

  create_table "contacts", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "first_name"
    t.string "middle_name"
    t.string "last_name"
    t.string "title"
    t.string "country"
    t.string "city"
    t.boolean "is_admin", default: false
    t.jsonb "country_obj"
    t.string "avatar"
    t.string "state"
    t.jsonb "state_obj"
    t.string "address"
    t.string "postal_code"
    t.boolean "all_categories", default: false
    t.uuid "timezone_id"
    t.uuid "user_id"
    t.uuid "contactable_id"
    t.string "contactable_type"
    t.string "designation"
    t.string "department_name"
    t.uuid "hiring_organization_id"
    t.boolean "enable", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "locked_at"
    t.index ["deleted_at", "contactable_id", "contactable_type"], name: "index_contacts_on_contactable_id_and_contactable_type"
    t.index ["deleted_at", "hiring_organization_id"], name: "index_contacts_on_hiring_organization_id"
    t.index ["deleted_at", "timezone_id"], name: "index_contacts_on_timezone_id"
    t.index ["deleted_at", "user_id"], name: "index_contacts_on_user_id"
  end

  create_table "countries", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbr"
    t.integer "position"
    t.boolean "truncated", default: true
  end

  create_table "countries_currencies", id: false, force: :cascade do |t|
    t.uuid "country_id", null: false
    t.uuid "currency_id", null: false
    t.index ["country_id"], name: "index_countries_currencies_on_country_id"
    t.index ["currency_id"], name: "index_countries_currencies_on_currency_id"
  end

  create_table "countries_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "country_id"
    t.index ["country_id", "user_id"], name: "index_countries_users_on_country_id_and_user_id"
  end

  create_table "csmm_scores", primary_key: ["from_type", "from_id", "to_type", "to_id"], force: :cascade do |t|
    t.text "from_type", null: false
    t.uuid "from_id", null: false
    t.text "to_type", null: false
    t.uuid "to_id", null: false
    t.float "score"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["from_id"], name: "csmm_scores_from_id_idx"
    t.index ["from_type"], name: "csmm_scores_from_type_idx"
    t.index ["to_id"], name: "csmm_scores_to_id_idx"
    t.index ["to_type"], name: "csmm_scores_to_type_idx"
  end

  create_table "currencies", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbr"
  end

  create_table "data_migrations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "version"
  end

  create_table "degrees", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "name"
    t.integer "popularity", default: 0
  end

  create_table "educations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "school"
    t.text "degree"
    t.string "city"
    t.string "country"
    t.date "start_date"
    t.date "end_date"
    t.boolean "studying"
    t.jsonb "country_obj"
    t.uuid "embeddable_id"
    t.string "embeddable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["embeddable_type", "embeddable_id"], name: "index_educations_on_embeddable"
  end

  create_table "emails", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "type"
    t.string "email"
    t.boolean "primary"
    t.uuid "mailable_id"
    t.string "mailable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "confirmation_token"
    t.string "unconfirmed_email"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.index ["deleted_at", "mailable_type", "mailable_id"], name: "index_emails_on_mailable_type_and_mailable_id"
    t.index ["id", "deleted_at"], name: "index_emails_on_id_and_deleted_at"
  end

  create_table "event_attendees", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "email"
    t.uuid "user_id"
    t.uuid "talent_id"
    t.uuid "event_id"
    t.boolean "optional", default: false
    t.boolean "is_host", default: false
    t.boolean "is_organizer", default: false
    t.string "status", default: "pending"
    t.string "invitation_token"
    t.text "note"
    t.boolean "remove_event", default: false
    t.string "confirmed_slots", default: [], array: true
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_attendees_on_event_id"
    t.index ["talent_id"], name: "index_event_attendees_on_talent_id"
    t.index ["user_id"], name: "index_event_attendees_on_user_id"
  end

  create_table "events", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "event_type"
    t.boolean "request", default: false
    t.string "title"
    t.string "link"
    t.integer "reminder_in_minutes", default: 0
    t.string "repeat", default: "Never"
    t.text "location"
    t.text "note"
    t.datetime "start_date_time"
    t.datetime "end_date_time"
    t.uuid "job_id"
    t.string "latitude"
    t.string "longitude"
    t.string "token"
    t.text "meeting_url"
    t.string "dial_in_number"
    t.string "access_code"
    t.boolean "declined", default: false
    t.boolean "confirmed", default: false
    t.text "decline_reason"
    t.text "optional_note"
    t.uuid "parent_id"
    t.uuid "user_id"
    t.string "declined_by_type"
    t.uuid "declined_by_id"
    t.string "related_to_type"
    t.uuid "related_to_id"
    t.uuid "client_id"
    t.uuid "tj_user_id"
    t.uuid "agency_id"
    t.boolean "active", default: true
    t.text "update_note"
    t.uuid "timezone_id"
    t.index ["deleted_at", "declined_by_id", "declined_by_type"], name: "index_events_on_declined_by_id_and_declined_by_type"
    t.index ["deleted_at", "job_id", "related_to_id", "related_to_type", "agency_id", "user_id"], name: "events_job_related_to_tj_agency"
    t.index ["deleted_at", "job_id", "related_to_id", "related_to_type", "client_id", "user_id"], name: "events_job_related_to_client"
    t.index ["deleted_at", "job_id", "related_to_id", "related_to_type", "tj_user_id", "user_id"], name: "events_job_related_to_tj_user"
    t.index ["timezone_id"], name: "index_events_on_timezone_id"
  end

  create_table "events_talents", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "event_id"
    t.uuid "talent_id"
    t.index ["event_id"], name: "index_events_talents_on_event_id"
    t.index ["talent_id"], name: "index_events_talents_on_talent_id"
  end

  create_table "events_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "event_id"
    t.uuid "user_id"
    t.index ["event_id"], name: "index_events_users_on_event_id"
    t.index ["user_id"], name: "index_events_users_on_user_id"
  end

  create_table "experiences", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "title"
    t.text "company"
    t.string "city"
    t.string "country"
    t.date "start_date"
    t.date "end_date"
    t.boolean "working", default: false
    t.text "description"
    t.jsonb "country_obj"
    t.uuid "embeddable_id"
    t.string "embeddable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["embeddable_type", "embeddable_id"], name: "index_experiences_on_embeddable"
  end

  create_table "favorites", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid "user_id"
    t.uuid "talents_job_id"
    t.index ["talents_job_id"], name: "index_favorites_on_talents_job_id"
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "groups", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "name"
    t.text "logo"
    t.boolean "image_resized", default: true
    t.boolean "enabled", default: true
    t.text "description"
    t.uuid "hiring_organization_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "created_by_id"
    t.string "logo_50_public"
    t.string "logo_100_public"
    t.datetime "locked_at"
    t.index ["created_by_id"], name: "index_groups_on_created_by_id"
    t.index ["deleted_at", "created_by_id"], name: "index_groups_on_deleted_at_and_created_by_id"
    t.index ["hiring_organization_id"], name: "index_groups_on_hiring_organization_id"
    t.index ["id", "deleted_at"], name: "index_groups_on_id_and_deleted_at"
  end

  create_table "groups_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "group_id"
    t.index ["group_id"], name: "index_groups_users_on_group_id"
    t.index ["user_id"], name: "index_groups_users_on_user_id"
  end

  create_table "hiring_organizations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "company_relationship"
    t.string "company_relationship_name"
    t.text "logo"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.jsonb "state_obj"
    t.jsonb "country_obj"
    t.boolean "image_resized", default: false
    t.boolean "enable", default: true
    t.uuid "client_id"
    t.uuid "created_by_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.boolean "confirmed", default: false
    t.boolean "invite_to_cs"
    t.string "initials"
    t.text "about"
    t.string "logo_100_public"
    t.string "logo_50_public"
    t.datetime "locked_at"
    t.datetime "verified_at"
    t.index ["deleted_at", "client_id"], name: "index_hiring_organizations_on_client_id"
    t.index ["deleted_at", "company_relationship_name"], name: "index_ho_company_relationship_name"
    t.index ["deleted_at", "created_by_id"], name: "index_hiring_organizations_on_created_by_id"
    t.index ["deleted_at", "id"], name: "index_hiring_organizations_on_id_and_deleted_at"
  end

  create_table "ho_jobs_watchers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "job_id"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_ho_jobs_watchers_on_job_id"
    t.index ["user_id"], name: "index_ho_jobs_watchers_on_user_id"
  end

  create_table "identities", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "provider"
    t.string "uid"
    t.uuid "talent_id"
    t.index ["talent_id"], name: "index_identities_on_talent_id"
  end

  create_table "impressions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "impressionable_type"
    t.uuid "impressionable_id"
    t.uuid "user_id"
    t.string "controller_name"
    t.string "action_name"
    t.string "view_name"
    t.string "request_hash"
    t.string "ip_address"
    t.string "session_hash"
    t.text "message"
    t.text "referrer"
    t.text "params"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["controller_name", "action_name", "ip_address"], name: "controlleraction_ip_index"
    t.index ["controller_name", "action_name", "request_hash"], name: "controlleraction_request_index"
    t.index ["controller_name", "action_name", "session_hash"], name: "controlleraction_session_index"
    t.index ["impressionable_type", "impressionable_id", "ip_address"], name: "poly_ip_index"
    t.index ["impressionable_type", "impressionable_id", "params"], name: "poly_params_request_index"
    t.index ["impressionable_type", "impressionable_id", "request_hash"], name: "poly_request_index"
    t.index ["impressionable_type", "impressionable_id", "session_hash"], name: "poly_session_index"
    t.index ["impressionable_type", "message", "impressionable_id"], name: "impressionable_type_message_index"
    t.index ["user_id"], name: "index_impressions_on_user_id"
  end

  create_table "industries", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "name"
    t.string "_group", default: [], array: true
    t.integer "code"
    t.index ["deleted_at", "id", "name"], name: "index_industries_on_id_and_name"
  end

  create_table "industries_profiles", id: false, force: :cascade do |t|
    t.uuid "industry_id", null: false
    t.uuid "profile_id", null: false
    t.index ["industry_id"], name: "index_industries_profiles_on_industry_id"
    t.index ["profile_id"], name: "index_industries_profiles_on_profile_id"
  end

  create_table "industries_talent_preferences", id: false, force: :cascade do |t|
    t.uuid "industry_id", null: false
    t.uuid "talent_preference_id", null: false
    t.index ["industry_id"], name: "index_industries_talent_preferences_on_industry_id"
    t.index ["talent_preference_id"], name: "index_industries_talent_preferences_on_talent_preference_id"
  end

  create_table "industries_talents", id: false, force: :cascade do |t|
    t.uuid "industry_id", null: false
    t.uuid "talent_id", null: false
    t.index ["industry_id", "talent_id"], name: "index_industries_talents_on_industry_id_and_talent_id"
  end

  create_table "industries_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "industry_id"
    t.index ["industry_id", "user_id"], name: "index_industries_users_on_industry_id_and_user_id"
  end

  create_table "interview_slots", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "slot"
    t.string "note"
    t.uuid "talent_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["deleted_at", "talent_id"], name: "index_interview_slots_on_talent_id"
  end

  create_table "job_manual_invite_requests", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "expire_at"
    t.integer "number_of_invitations"
    t.string "status"
    t.string "note"
    t.uuid "job_id"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_job_manual_invite_requests_on_job_id"
    t.index ["user_id"], name: "index_job_manual_invite_requests_on_user_id"
  end

  create_table "job_providers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "job_id"
    t.jsonb "data"
    t.string "name"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_job_providers_on_job_id"
  end

  create_table "jobs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.string "job_id"
    t.string "title"
    t.string "stage", default: "Draft"
    t.integer "positions"
    t.integer "available_positions"
    t.date "start_date"
    t.text "summary"
    t.datetime "published_at"
    t.float "earnings", default: 0.0
    t.text "minimum_qualification"
    t.text "preferred_qualification"
    t.text "responsibilities"
    t.text "additional_detail"
    t.integer "no_of_views", default: 0
    t.jsonb "years_of_experience"
    t.string "work_permits", default: [], array: true
    t.string "certifications", default: [], array: true
    t.string "location_type"
    t.boolean "enable", default: false
    t.text "logo"
    t.string "type_of_job"
    t.string "duration"
    t.string "duration_period"
    t.string "currency"
    t.jsonb "currency_obj"
    t.string "pay_period"
    t.jsonb "bill_rate", default: {"value"=>0, "markup"=>true}
    t.float "net_margin", default: 0.0
    t.jsonb "agency_commission", default: {"value"=>0, "markup"=>true}
    t.jsonb "placement_commission", default: {"value"=>0, "markup"=>true}
    t.float "total_value_of_contract", default: 0.0
    t.float "total_crowdstaffing_profit", default: 0.0
    t.float "total_agency_payout", default: 0.0
    t.float "total_msp_vms_fee", default: 0.0
    t.float "agency_payout", default: 0.0
    t.float "crowdstaffing_profit", default: 0.0
    t.float "total_net_margin", default: 0.0
    t.float "msp_vms_fee_rate", default: 0.0
    t.float "employee_cost", default: 0.0
    t.text "reason_to_close_job"
    t.boolean "is_onhold", default: false
    t.text "reason_to_onhold_job"
    t.text "reason_to_unhold_job"
    t.string "benefits", default: [], array: true
    t.string "max_applied_limit"
    t.integer "priority_of_status"
    t.boolean "is_private", default: false
    t.boolean "private_client", default: false
    t.boolean "publish_to_cs", default: true
    t.datetime "closed_at"
    t.text "reason_to_reopen"
    t.uuid "client_id"
    t.uuid "industry_id"
    t.uuid "created_by_id"
    t.uuid "updated_by_id"
    t.uuid "published_by_id"
    t.uuid "timezone_id"
    t.uuid "category_id"
    t.uuid "account_manager_id"
    t.uuid "onboarding_agent_id"
    t.uuid "supervisor_id"
    t.boolean "image_resized"
    t.uuid "billing_term_id"
    t.uuid "hiring_organization_id"
    t.float "latitude", default: 0.0
    t.float "longitude", default: 0.0
    t.boolean "sync_status_from_job_provider", default: false
    t.jsonb "suggested_pay_rate_range", default: {"max"=>0, "min"=>0}
    t.boolean "is_bill_rate", default: false
    t.string "incumbent_bill_period"
    t.boolean "notification_to_candidates_on_close", default: true
    t.boolean "notification_to_suppliers_on_close", default: true
    t.text "closed_note"
    t.integer "filled_positions"
    t.datetime "on_hold_at"
    t.datetime "opened_at"
    t.datetime "exclusive_access_end_time"
    t.uuid "hiring_manager_id"
    t.boolean "enable_shareable_link", default: false
    t.boolean "publishing_privacy_setting", default: false
    t.boolean "publish_cs_facebook", default: false
    t.boolean "publish_agency_career", default: false
    t.boolean "publish_agency_facebook", default: false
    t.string "order_id"
    t.text "recruiter_tips"
    t.datetime "ho_published_at"
    t.boolean "visible_to_cs", default: true
    t.jsonb "incumbent_bill_rate", default: {"max"=>0.0, "min"=>0.0}
    t.boolean "guarantee_hire", default: false
    t.jsonb "suggested_pay_rate", default: {}
    t.jsonb "marketplace_reward", default: {}
    t.jsonb "expected_margin", default: {}
    t.string "cs_job_id"
    t.string "display_job_id"
    t.float "job_score", default: 0.0
    t.jsonb "goals", default: {}
    t.boolean "enable_questionnaire", default: false
    t.jsonb "stage_transitions", default: {}
    t.integer "popularity", default: 0
    t.datetime "locked_at"
    t.boolean "clone_job", default: false
    t.index ["deleted_at", "account_manager_id"], name: "index_jobs_on_account_manager_id"
    t.index ["deleted_at", "billing_term_id"], name: "index_jobs_on_billing_term_id"
    t.index ["deleted_at", "category_id"], name: "index_jobs_on_category_id"
    t.index ["deleted_at", "client_id"], name: "index_jobs_on_client_id"
    t.index ["deleted_at", "created_by_id"], name: "index_jobs_on_created_by_id"
    t.index ["deleted_at", "hiring_manager_id"], name: "index_jobs_on_deleted_at_and_hiring_manager_id"
    t.index ["deleted_at", "hiring_organization_id"], name: "index_jobs_on_hiring_organization_id"
    t.index ["deleted_at", "industry_id"], name: "index_jobs_on_industry_id"
    t.index ["deleted_at", "job_id"], name: "index_jobs_on_job_id"
    t.index ["deleted_at", "onboarding_agent_id"], name: "index_jobs_on_onboarding_agent_id"
    t.index ["deleted_at", "published_by_id"], name: "index_jobs_on_published_by_id"
    t.index ["deleted_at", "supervisor_id"], name: "index_jobs_on_supervisor_id"
    t.index ["deleted_at", "timezone_id"], name: "index_jobs_on_timezone_id"
    t.index ["deleted_at", "updated_by_id"], name: "index_jobs_on_updated_by_id"
    t.index ["display_job_id", "cs_job_id"], name: "index_jobs_on_display_job_id_and_cs_job_id"
    t.index ["hiring_manager_id"], name: "index_jobs_on_hiring_manager_id"
    t.index ["id", "deleted_at"], name: "index_jobs_on_id_and_deleted_at"
  end

  create_table "jobs_saved_by", id: false, force: :cascade do |t|
    t.uuid "job_id"
    t.uuid "talent_id"
    t.index ["job_id", "talent_id"], name: "index_jobs_saved_by_on_job_id_and_talent_id"
    t.index ["job_id"], name: "index_jobs_saved_by_on_job_id"
    t.index ["talent_id"], name: "index_jobs_saved_by_on_talent_id"
  end

  create_table "jobs_skills", id: false, force: :cascade do |t|
    t.uuid "job_id"
    t.uuid "skill_id"
    t.index ["job_id"], name: "index_jobs_skills_on_job_id"
    t.index ["skill_id"], name: "index_jobs_skills_on_skill_id"
  end

  create_table "jobs_talents", id: false, force: :cascade do |t|
    t.uuid "job_id"
    t.uuid "talent_id"
    t.index ["job_id", "talent_id"], name: "index_jobs_talents_on_job_id_and_talent_id"
  end

  create_table "languages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "proficiency"
    t.uuid "embeddable_id"
    t.string "embeddable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["embeddable_type", "embeddable_id"], name: "index_languages_on_embeddable"
  end

  create_table "links", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "type"
    t.text "link"
    t.uuid "embeddable_id"
    t.string "embeddable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["deleted_at", "embeddable_id", "embeddable_type"], name: "index_links_on_embeddable_id_and_embeddable_type"
  end

  create_table "locations", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "country"
    t.string "state"
    t.string "city"
    t.string "address"
  end

  create_table "locations_talent_preferences", id: false, force: :cascade do |t|
    t.uuid "location_id", null: false
    t.uuid "talent_preference_id", null: false
    t.index ["location_id"], name: "index_locations_talent_preferences_on_location_id"
    t.index ["talent_preference_id"], name: "index_locations_talent_preferences_on_talent_preference_id"
  end

  create_table "log_activities", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "url"
    t.jsonb "params"
    t.string "loggable_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "loggable_id"
    t.string "ip_address"
    t.index ["loggable_type", "loggable_id"], name: "index_log_activities_on_loggable_type_and_loggable_id"
  end

  create_table "mailboxes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.jsonb "from"
    t.jsonb "to"
    t.jsonb "cc"
    t.string "dkim"
    t.string "subject"
    t.string "email"
    t.float "spam_score"
    t.string "sender_ip"
    t.string "spam_report"
    t.jsonb "envelope"
    t.jsonb "charset"
    t.string "spf"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "matching_job_titles", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbr"
  end

  create_table "media", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.text "file"
    t.text "title"
    t.text "description"
    t.boolean "public", default: true
    t.uuid "mediable_id"
    t.string "mediable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["deleted_at", "mediable_type", "mediable_id"], name: "index_medium_on_mediable"
  end

  create_table "mentioned_notes_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "note_id"
    t.uuid "user_id"
    t.index ["note_id"], name: "index_mentioned_notes_users_on_note_id"
    t.index ["user_id"], name: "index_mentioned_notes_users_on_user_id"
  end

  create_table "mentioned_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "talents_job_id"
    t.uuid "user_id"
    t.string "mentionable_users", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["talents_job_id"], name: "index_mentioned_users_on_talents_job_id"
    t.index ["user_id"], name: "index_mentioned_users_on_user_id"
  end

  create_table "messages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "subject"
    t.text "body"
    t.string "attachments", default: [], array: true
    t.uuid "parent_ids", default: [], array: true
    t.string "tags", default: [], array: true
    t.string "send_via"
    t.jsonb "receiver_metadata"
    t.jsonb "related_objects"
    t.string "sendgrid_category", default: [], array: true
    t.jsonb "sendgrid_template_params", default: {}
    t.string "status"
    t.text "bounce_content"
  end

  create_table "messages_old", id: false, force: :cascade do |t|
    t.uuid "id"
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "subject"
    t.text "body"
    t.string "sender_email"
    t.string "emails", array: true
    t.string "attachments", array: true
    t.jsonb "uniq_args"
    t.string "sendable_type"
    t.uuid "sendable_id"
    t.string "support_emails", array: true
    t.uuid "parent_ids", array: true
    t.string "tags", array: true
    t.string "send_via"
    t.jsonb "receiver_metadata"
    t.jsonb "related_objects"
    t.string "sendgrid_category", array: true
    t.jsonb "sendgrid_template_params"
    t.string "status"
  end

  create_table "metrics_snapshots", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "key"
    t.jsonb "value"
    t.uuid "object_id"
    t.string "object_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "metrics_stages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "stage"
    t.boolean "if_interview"
    t.uuid "user_id"
    t.uuid "talents_job_id"
    t.uuid "job_id"
    t.uuid "client_id"
    t.uuid "billing_term_id"
    t.uuid "hiring_organization_id"
    t.uuid "agency_id"
    t.uuid "recruiter_id"
    t.boolean "offline"
    t.boolean "interested"
    t.float "sort_order"
    t.uuid "next_stage_id"
    t.uuid "previous_stage_id"
    t.integer "transition_time"
    t.index ["deleted_at", "agency_id"], name: "index_metrics_stages_on_agency_id"
    t.index ["deleted_at", "billing_term_id"], name: "index_metrics_stages_on_billing_term_id"
    t.index ["deleted_at", "client_id"], name: "index_metrics_stages_on_client_id"
    t.index ["deleted_at", "hiring_organization_id"], name: "index_metrics_stages_on_hiring_organization_id"
    t.index ["deleted_at", "job_id"], name: "index_metrics_stages_on_job_id"
    t.index ["deleted_at", "recruiter_id"], name: "index_metrics_stages_on_recruiter_id"
    t.index ["deleted_at", "talents_job_id"], name: "index_metrics_stages_on_talents_job_id"
    t.index ["deleted_at", "user_id"], name: "index_metrics_stages_on_user_id"
  end

  create_table "msp_names", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.index ["id", "deleted_at"], name: "index_msp_names_on_id_and_deleted_at"
  end

  create_table "notes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "note"
    t.string "old_visibility"
    t.boolean "announcement", default: false
    t.uuid "user_id"
    t.uuid "parent_id"
    t.string "notable_type"
    t.uuid "notable_id"
    t.string "visibility"
    t.index ["deleted_at", "notable_id", "notable_type"], name: "index_notes_on_notable_id_and_notable_type"
    t.index ["deleted_at", "parent_id"], name: "index_notes_on_parent_id"
    t.index ["deleted_at", "user_id"], name: "index_notes_on_user_id"
    t.index ["visibility"], name: "index_notes_on_visibility"
  end

  create_table "notifications", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "key", default: "custom"
    t.text "label", default: "custom"
    t.text "message"
    t.boolean "read", default: false
    t.boolean "viewed_or_emailed", default: false
    t.boolean "hide", default: false
    t.boolean "by_internal_user", default: false
    t.boolean "show_on_timeline", default: true
    t.jsonb "user_agent"
    t.text "visibility"
    t.jsonb "specific_obj", default: {}
    t.string "receiver_type"
    t.uuid "receiver_id"
    t.string "from_type"
    t.uuid "from_id"
    t.string "object_type"
    t.uuid "object_id"
    t.uuid "agency_id"
    t.text "non_visibility"
    t.index ["deleted_at", "agency_id"], name: "index_notifications_on_agency_id"
    t.index ["deleted_at", "from_id", "from_type"], name: "index_notifications_on_from_id_and_from_type"
    t.index ["deleted_at", "object_id", "object_type"], name: "index_notifications_on_object_id_and_object_type"
    t.index ["deleted_at", "receiver_id", "receiver_type"], name: "index_notifications_on_receiver_id_and_receiver_type"
    t.index ["id", "deleted_at"], name: "index_notifications_on_id_and_deleted_at"
    t.index ["show_on_timeline", "key"], name: "show_on_timeline_on_key"
    t.index ["visibility", "non_visibility"], name: "notification_visibility_non_visibility_index"
  end

  create_table "offer_extensions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "address"
    t.text "city"
    t.text "state"
    t.text "country"
    t.text "postal_code"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.text "location"
    t.float "duration"
    t.text "duration_period"
    t.float "salary"
    t.text "pay_period"
    t.float "hours_per_week"
    t.date "start_date"
    t.text "reject_reason"
    t.text "reject_notes"
    t.datetime "shift_start"
    t.datetime "shift_length"
    t.string "benefits", default: [], array: true
    t.boolean "send_as_representer", default: false
    t.boolean "benefits_added", default: false
    t.uuid "updated_by_id"
    t.string "start_time"
    t.string "end_time"
    t.boolean "possibility_of_extension", default: false
    t.date "end_date"
    t.text "incumbent_bill_period"
    t.text "welcome_message"
    t.text "exit_message"
    t.text "additional_notes"
    t.text "subject"
    t.boolean "notify_collaborators", default: false
    t.boolean "cancel", default: false
    t.text "reason_note"
    t.uuid "offer_letter_id"
    t.uuid "talents_job_id"
    t.uuid "timezone_id"
    t.uuid "user_id"
    t.uuid "completed_transition_id"
    t.float "incumbent_bill_rate"
    t.index ["completed_transition_id"], name: "index_offer_extensions_on_completed_transition_id"
    t.index ["offer_letter_id"], name: "index_offer_extensions_on_offer_letter_id"
    t.index ["talents_job_id"], name: "index_offer_extensions_on_talents_job_id"
    t.index ["timezone_id"], name: "index_offer_extensions_on_timezone_id"
    t.index ["user_id"], name: "index_offer_extensions_on_user_id"
  end

  create_table "offer_letters", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.string "location"
    t.float "duration"
    t.string "duration_period"
    t.float "salary"
    t.string "pay_period"
    t.float "hours_per_week"
    t.date "start_date"
    t.string "reject_reason"
    t.string "reject_notes"
    t.datetime "shift_start"
    t.datetime "shift_length"
    t.string "benefits", default: [], array: true
    t.boolean "send_as_representer", default: false
    t.boolean "benefits_added", default: false
    t.uuid "updated_by_id"
    t.uuid "completed_transition_id"
    t.uuid "timezone_id"
    t.string "start_time"
    t.string "end_time"
    t.uuid "talents_job_id"
    t.boolean "possibility_of_extension", default: false
    t.date "end_date"
    t.text "incumbent_bill_period"
    t.text "welcome_message"
    t.text "exit_message"
    t.text "additional_notes"
    t.text "subject"
    t.boolean "notify_collaborators", default: false
    t.boolean "cancel", default: false
    t.text "reason_note"
    t.text "recipient"
    t.float "incumbent_bill_rate"
    t.index ["completed_transition_id", "updated_at", "id"], name: "offer_ct_updated_id"
    t.index ["talents_job_id"], name: "index_offer_letters_on_talents_job_id"
    t.index ["timezone_id"], name: "index_offer_letters_on_timezone_id"
    t.index ["updated_by_id"], name: "index_offer_letters_on_updated_by_id"
  end

  create_table "onboarding_documents", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "document_type"
    t.text "file"
    t.string "title"
    t.text "description"
    t.string "visible"
    t.integer "rank"
    t.uuid "onboarding_package_id"
    t.index ["onboarding_package_id"], name: "index_onboarding_documents_on_onboarding_package_id"
  end

  create_table "onboarding_packages", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.text "description"
    t.uuid "created_by_id"
    t.uuid "embeddable_id"
    t.string "embeddable_type"
    t.index ["deleted_at", "created_by_id"], name: "index_onboarding_packages_on_created_by_id"
    t.index ["deleted_at", "embeddable_type", "embeddable_id"], name: "index_onboarding_packages_on_embeddable"
  end

  create_table "onboards", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.uuid "onboarding_document_id"
    t.boolean "action_completed", default: false
    t.string "status", default: "pending"
    t.string "file"
    t.uuid "talents_job_id"
    t.index ["deleted_at", "onboarding_document_id"], name: "index_onboards_on_onboarding_document_id"
    t.index ["deleted_at", "talents_job_id"], name: "index_onboards_on_talents_job_id"
  end

  create_table "pghero_query_stats", force: :cascade do |t|
    t.text "database"
    t.text "user"
    t.text "query"
    t.bigint "query_hash"
    t.float "total_time"
    t.bigint "calls"
    t.datetime "captured_at"
    t.index ["database", "captured_at"], name: "index_pghero_query_stats_on_database_and_captured_at"
  end

  create_table "phones", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "type"
    t.string "number"
    t.boolean "primary"
    t.uuid "callable_id"
    t.string "callable_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "confirmed", default: false
    t.string "extension"
    t.index ["deleted_at", "callable_type", "callable_id"], name: "index_phones_on_callable_type_and_callable_id"
    t.index ["id", "deleted_at"], name: "index_phones_on_id_and_deleted_at"
  end

  create_table "pipeline_notifications", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "stage"
    t.boolean "rejected", default: false
    t.boolean "withdrawn", default: false
    t.uuid "user_id"
    t.uuid "talents_job_id"
    t.uuid "created_by_id"
    t.index ["created_by_id"], name: "index_pipeline_notifications_on_created_by_id"
    t.index ["talents_job_id"], name: "index_pipeline_notifications_on_talents_job_id"
    t.index ["user_id"], name: "index_pipeline_notifications_on_user_id"
  end

  create_table "pipeline_steps", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "stage_type"
    t.string "stage_label"
    t.text "stage_description"
    t.float "stage_order", default: 0.0
    t.boolean "fixed", default: false
    t.boolean "visible", default: true
    t.integer "count", default: 0
    t.boolean "eventable", default: false
    t.uuid "recruitment_pipeline_id"
    t.index ["recruitment_pipeline_id"], name: "index_pipeline_steps_on_recruitment_pipeline_id"
  end

  create_table "positions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.string "name"
  end

  create_table "positions_profiles", id: false, force: :cascade do |t|
    t.uuid "position_id", null: false
    t.uuid "profile_id", null: false
    t.index ["position_id"], name: "index_positions_profiles_on_position_id"
    t.index ["profile_id"], name: "index_positions_profiles_on_profile_id"
  end

  create_table "positions_talent_preferences", id: false, force: :cascade do |t|
    t.uuid "talent_preference_id", null: false
    t.uuid "position_id", null: false
    t.index ["position_id"], name: "index_positions_talent_preferences_on_position_id"
    t.index ["talent_preference_id"], name: "index_positions_talent_preferences_on_talent_preference_id"
  end

  create_table "positions_talents", id: false, force: :cascade do |t|
    t.uuid "position_id", null: false
    t.uuid "talent_id", null: false
    t.index ["position_id", "talent_id"], name: "index_positions_talents_on_position_id_and_talent_id"
  end

  create_table "positions_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "position_id"
    t.index ["position_id", "user_id"], name: "index_positions_users_on_position_id_and_user_id"
  end

  create_table "potential_earnings", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.jsonb "bill_rate", default: {"value"=>0, "markup"=>true}
    t.jsonb "agency_commission", default: {"value"=>0, "markup"=>true}
    t.jsonb "placement_commission", default: {"value"=>0, "markup"=>true}
    t.float "net_margin", default: 0.0
    t.float "total_value_of_contract", default: 0.0
    t.float "total_crowdstaffing_profit", default: 0.0
    t.float "total_agency_payout", default: 0.0
    t.float "total_msp_vms_fee", default: 0.0
    t.float "agency_payout"
    t.float "crowdstaffing_profit"
    t.float "total_net_margin", default: 0.0
    t.float "msp_vms_fee_rate", default: 0.0
    t.float "employee_cost", default: 0.0
    t.uuid "user_id"
    t.uuid "job_id"
    t.index ["job_id"], name: "index_potential_earnings_on_job_id"
    t.index ["user_id"], name: "index_potential_earnings_on_user_id"
  end

  create_table "profiles", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "summary"
    t.boolean "willing_to_relocate"
    t.string "current_benefits", default: [], array: true
    t.string "hobbies", default: [], array: true
    t.string "work_authorization", default: [], array: true
    t.string "current_pay_range_min"
    t.string "current_pay_range_max"
    t.string "current_pay_period"
    t.string "current_currency"
    t.jsonb "current_currency_obj"
    t.string "expected_pay_range_min"
    t.string "expected_pay_range_max"
    t.string "expected_pay_period"
    t.string "expected_currency"
    t.jsonb "expected_currency_obj"
    t.text "compensation_notes"
    t.string "compensation_benefits", default: [], array: true
    t.boolean "if_completed", default: false
    t.integer "sin"
    t.text "avatar"
    t.string "headline"
    t.uuid "timezone_id"
    t.uuid "matching_job_title_id"
    t.string "title"
    t.string "profilable_type"
    t.uuid "profilable_id"
    t.uuid "talent_id"
    t.boolean "my_candidate", default: false
    t.uuid "agency_id"
    t.jsonb "years_of_experience"
    t.string "salutation"
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.string "email"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.jsonb "state_obj"
    t.jsonb "country_obj"
    t.uuid "hiring_organization_id"
    t.float "latitude", default: 0.0
    t.float "longitude", default: 0.0
    t.index ["deleted_at", "hiring_organization_id"], name: "index_profiles_on_hiring_organization_id"
    t.index ["deleted_at", "matching_job_title_id"], name: "index_profiles_on_matching_job_title_id"
    t.index ["deleted_at", "profilable_id", "profilable_type"], name: "index_profiles_on_profilable_id_and_profilable_type"
    t.index ["deleted_at", "talent_id"], name: "index_profiles_on_talent_id"
    t.index ["deleted_at", "timezone_id"], name: "index_profiles_on_timezone_id"
    t.index ["id", "deleted_at"], name: "index_profiles_on_id_and_deleted_at"
  end

  create_table "profiles_skills", id: false, force: :cascade do |t|
    t.uuid "profile_id", null: false
    t.uuid "skill_id", null: false
    t.index ["profile_id"], name: "index_profiles_skills_on_profile_id"
    t.index ["skill_id"], name: "index_profiles_skills_on_skill_id"
  end

  create_table "proprietary_platforms", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
  end

  create_table "questionnaire_answers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "talent_answer"
    t.string "answerable_type"
    t.uuid "answerable_id"
    t.boolean "is_shared", default: false
    t.integer "page_number"
    t.boolean "mandatory", default: false
    t.boolean "score_question", default: false
    t.boolean "is_date", default: false
    t.boolean "is_time", default: false
    t.boolean "is_range", default: false
    t.integer "rating_scale"
    t.string "rating_shape"
    t.string "shape_color"
    t.boolean "is_option_label", default: false
    t.jsonb "options", default: {}
    t.boolean "is_liked"
    t.float "talent_rating"
    t.text "question"
    t.string "type_of_question"
    t.integer "display_order"
    t.uuid "rtr_id"
    t.index ["answerable_id", "answerable_type"], name: "questionnaire_answers_on_answerable"
    t.index ["rtr_id"], name: "index_questionnaire_answers_on_rtr_id"
  end

  create_table "questionnaires", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "questionable_id"
    t.string "questionable_type"
    t.index ["questionable_type", "questionable_id"], name: "index_questionnaire_on_questionable"
  end

  create_table "questions", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "question"
    t.string "type_of_question"
    t.uuid "questionnaire_id"
    t.integer "display_order", null: false
    t.boolean "is_shared", default: false
    t.integer "page_number"
    t.boolean "mandatory", default: false
    t.uuid "user_id"
    t.boolean "score_question", default: false
    t.boolean "is_date", default: false
    t.boolean "is_time", default: false
    t.boolean "is_range", default: false
    t.integer "rating_scale"
    t.string "rating_shape"
    t.string "shape_color"
    t.boolean "is_option_label", default: false
    t.jsonb "options", default: {}
    t.boolean "removed", default: false
    t.index ["questionnaire_id"], name: "index_questions_on_questionnaire_id"
    t.index ["user_id"], name: "index_questions_on_user_id"
  end

  create_table "questions_templates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "question_id"
    t.uuid "template_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_questions_templates_on_question_id"
    t.index ["template_id"], name: "index_questions_templates_on_template_id"
  end

  create_table "read_bill_rates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "bill_rate_negotiation_id"
    t.uuid "user_id"
    t.index ["bill_rate_negotiation_id", "user_id"], name: "index_read_bill_rates_on_bill_rate_negotiation_id_and_user_id"
  end

  create_table "read_notes_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "note_id"
    t.uuid "user_id"
    t.boolean "read", default: false
    t.string "resource_type"
    t.uuid "resource_id"
    t.boolean "is_mentioned", default: false
    t.index ["note_id"], name: "index_read_notes_users_on_note_id"
    t.index ["resource_type", "resource_id"], name: "index_read_notes_users_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_read_notes_users_on_user_id"
  end

  create_table "read_offer_letters_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "offer_letter_id"
    t.uuid "user_id"
    t.index ["offer_letter_id", "user_id"], name: "index_read_offer_letters_users_on_offer_letter_id_and_user_id"
  end

  create_table "receivers", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "receiver_type"
    t.string "email"
    t.uuid "user_id"
    t.uuid "talent_id"
    t.uuid "message_id"
    t.datetime "delete_after_archived_time"
    t.boolean "featured", default: false
    t.string "open_via"
    t.jsonb "viewable_information", default: {}
    t.jsonb "sendgrid_status"
    t.boolean "send_email", default: true
    t.uuid "parent_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_receivers_on_message_id"
    t.index ["talent_id"], name: "index_receivers_on_talent_id"
    t.index ["user_id"], name: "index_receivers_on_user_id"
  end

  create_table "recruitment_pipelines", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.text "description"
    t.uuid "created_by_id"
    t.uuid "updated_by_id"
    t.uuid "embeddable_id"
    t.string "embeddable_type"
    t.index ["deleted_at", "created_by_id"], name: "index_recruitment_pipelines_on_created_by_id"
    t.index ["deleted_at", "embeddable_type", "embeddable_id"], name: "index_recruitment_pipeline_on_embeddable"
    t.index ["deleted_at", "updated_by_id"], name: "index_recruitment_pipelines_on_updated_by_id"
    t.index ["id", "deleted_at"], name: "index_recruitment_pipelines_on_id_and_deleted_at"
  end

  create_table "rejected_histories", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "rejected_reason"
    t.text "rejection_note"
    t.string "file"
    t.string "rejected_by_type"
    t.uuid "rejected_by_id"
    t.string "rejected_to_type"
    t.uuid "rejected_to_id"
    t.uuid "onboard_id"
    t.uuid "client_id"
    t.index ["deleted_at", "client_id"], name: "index_rejected_histories_on_client_id"
    t.index ["deleted_at", "onboard_id"], name: "index_rejected_histories_on_onboard_id"
    t.index ["deleted_at", "rejected_by_id", "rejected_by_type"], name: "index_rejected_histories_on_rejected_by_id_and_rejected_by_type"
    t.index ["rejected_to_id", "rejected_to_type"], name: "index_rejected_histories_on_rejected_to_id_and_rejected_to_type"
  end

  create_table "reminders", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.integer "unit"
    t.string "duration_period"
    t.string "note"
    t.string "sidekiq_jid"
    t.string "status", default: "ACTIVE"
    t.datetime "reminder_at"
    t.uuid "user_id"
    t.uuid "profile_id"
    t.uuid "talent_id"
    t.uuid "agency_id"
    t.uuid "hiring_organization_id"
    t.uuid "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agency_id"], name: "index_reminders_on_agency_id"
    t.index ["created_by_id"], name: "index_reminders_on_created_by_id"
    t.index ["hiring_organization_id"], name: "index_reminders_on_hiring_organization_id"
    t.index ["profile_id"], name: "index_reminders_on_profile_id"
    t.index ["talent_id"], name: "index_reminders_on_talent_id"
    t.index ["user_id"], name: "index_reminders_on_user_id"
  end

  create_table "resume_templates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.text "content"
  end

  create_table "resumes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "resume_path"
    t.boolean "processed", default: false
    t.string "uploadable_type"
    t.uuid "uploadable_id"
    t.string "resume_path_pdf"
    t.boolean "master_resume", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean "if_primary", default: false
    t.index ["uploadable_id", "uploadable_type"], name: "index_resumes_on_uploadable_id_and_uploadable_type"
  end

  create_table "rtrs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.string "location"
    t.float "duration"
    t.string "duration_period"
    t.float "salary"
    t.string "pay_period"
    t.float "hours_per_week"
    t.date "start_date"
    t.datetime "shift_start"
    t.datetime "shift_length"
    t.datetime "signed_at"
    t.datetime "rejected_at"
    t.text "reject_reason"
    t.text "subject"
    t.text "body"
    t.string "tag", default: "Sent"
    t.boolean "benefits_added", default: false
    t.string "benefits", default: [], array: true
    t.boolean "offline", default: false
    t.text "offline_rtr_doc"
    t.boolean "send_as_representer", default: false
    t.uuid "updated_by_id"
    t.uuid "completed_transition_id"
    t.uuid "timezone_id"
    t.string "start_time"
    t.string "end_time"
    t.float "incumbent_bill_rate", default: 0.0
    t.string "incumbent_bill_period"
    t.uuid "talents_job_id"
    t.text "note"
    t.string "questionnaire_status"
    t.index ["completed_transition_id"], name: "index_rtrs_on_completed_transition_id"
    t.index ["signed_at", "rejected_at", "offline", "completed_transition_id", "updated_at"], name: "rtr_signed_rejected_offline_ct_updated"
    t.index ["talents_job_id"], name: "index_rtrs_on_talents_job_id"
    t.index ["timezone_id"], name: "index_rtrs_on_timezone_id"
    t.index ["updated_by_id"], name: "index_rtrs_on_updated_by_id"
  end

  create_table "saved_clients_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "client_id"
    t.index ["client_id", "user_id"], name: "index_saved_clients_users_on_client_id_and_user_id"
  end

  create_table "schools", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "name"
    t.integer "popularity", default: 0
  end

  create_table "sd_scores", primary_key: ["job_id", "recruiter_id"], force: :cascade do |t|
    t.uuid "job_id", null: false
    t.uuid "recruiter_id", null: false
    t.float "score"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "share_links", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "shared_id"
    t.string "shared_type"
    t.uuid "created_by_id"
    t.string "token"
    t.integer "visits", default: 0
    t.datetime "last_visited_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "agency_id"
    t.string "yourl_keyword"
    t.string "yourl_url"
    t.integer "clicks", default: 0
  end

  create_table "shareables", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "job_id"
    t.uuid "share_link_id"
    t.uuid "talent_id"
    t.boolean "existing_talent"
    t.uuid "user_id"
    t.string "yourl_keyword"
    t.string "referrer"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "visits", default: 0
    t.integer "unique_visits", default: 0
    t.string "ip_address"
    t.boolean "acknowledged", default: false
    t.index ["job_id"], name: "index_shareables_on_job_id"
    t.index ["share_link_id"], name: "index_shareables_on_share_link_id"
    t.index ["talent_id"], name: "index_shareables_on_talent_id"
    t.index ["user_id"], name: "index_shareables_on_user_id"
  end

  create_table "skills", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "source"
    t.index ["name"], name: "index_skills_on_name"
  end

  create_table "skills_talents", id: false, force: :cascade do |t|
    t.uuid "skill_id", null: false
    t.uuid "talent_id", null: false
    t.index ["skill_id", "talent_id"], name: "index_skills_talents_on_skill_id_and_talent_id"
  end

  create_table "skills_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "skill_id"
    t.index ["skill_id", "user_id"], name: "index_skills_users_on_skill_id_and_user_id"
  end

  create_table "sourced_for_jobs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "talent_id"
    t.uuid "job_id"
    t.boolean "sourced", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_sourced_for_jobs_on_job_id"
    t.index ["talent_id"], name: "index_sourced_for_jobs_on_talent_id"
    t.index ["user_id"], name: "index_sourced_for_jobs_on_user_id"
  end

  create_table "states", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.string "abbr"
    t.uuid "country_id"
    t.index ["country_id"], name: "index_states_on_country_id"
  end

  create_table "taggings", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "taggable_type"
    t.uuid "taggable_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable_type_and_taggable_id"
  end

  create_table "tags", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "talent_preferences", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.jsonb "experience_range"
    t.string "base_amount"
    t.string "pay_range_max"
    t.string "pay_period"
    t.string "currency"
    t.jsonb "currency_obj"
    t.string "benefits", default: [], array: true
    t.string "work_type", default: [], array: true
    t.string "working_hours", default: [], array: true
    t.uuid "talent_id"
    t.boolean "relocate", default: false
    t.boolean "relocation_assistance", default: false
    t.boolean "remote", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["talent_id"], name: "index_talent_preferences_on_talent_id"
  end

  create_table "talents", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "email", default: ""
    t.string "username"
    t.string "encrypted_password", default: ""
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "password_set_by_user", default: false
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "address"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "postal_code"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.text "summary"
    t.boolean "willing_to_relocate"
    t.string "current_benefits", default: [], array: true
    t.string "hobbies", default: [], array: true
    t.string "work_authorization", default: [], array: true
    t.string "current_pay_range_min"
    t.string "current_pay_range_max"
    t.string "current_pay_period"
    t.string "current_currency"
    t.jsonb "current_currency_obj"
    t.string "expected_pay_range_min"
    t.string "expected_pay_range_max"
    t.string "expected_pay_period"
    t.string "expected_currency"
    t.jsonb "expected_currency_obj"
    t.text "compensation_notes"
    t.string "compensation_benefits", default: [], array: true
    t.boolean "if_completed"
    t.integer "sin"
    t.text "avatar"
    t.string "headline"
    t.uuid "timezone_id"
    t.uuid "matching_job_title_id"
    t.string "source_of_profile"
    t.date "start_date"
    t.float "latitude", default: 0.0
    t.float "longitude", default: 0.0
    t.boolean "hired"
    t.boolean "send_emails", default: false
    t.boolean "contact_by_phone", default: true
    t.boolean "contact_by_email", default: true
    t.string "resume"
    t.text "resume_path"
    t.text "resume_path_pdf"
    t.boolean "parse_resume", default: false
    t.string "first_name"
    t.string "last_name"
    t.string "middle_name"
    t.string "salutation"
    t.jsonb "years_of_experience"
    t.boolean "image_resized", default: false
    t.string "status"
    t.datetime "last_updated_at"
    t.string "profile_status", default: "not applicable"
    t.datetime "daxtra_file_uploaded"
    t.uuid "added_by_id"
    t.uuid "last_updated_by_id"
    t.string "updated_by_type"
    t.uuid "updated_by_id"
    t.uuid "hired_talents_job_id"
    t.uuid "hired_by_id"
    t.text "resume_path_backup"
    t.text "resume_path_pdf_backup"
    t.datetime "password_updated_at"
    t.string "linkedinUrl"
    t.string "source"
    t.uuid "rtr_expire_job_id"
    t.uuid "last_invited_by_id"
    t.string "avatar_100_public"
    t.string "avatar_50_public"
    t.index ["deleted_at", "added_by_id"], name: "index_talents_on_added_by_id"
    t.index ["deleted_at", "hired_by_id"], name: "index_talents_on_hired_by_id"
    t.index ["deleted_at", "hired_talents_job_id"], name: "index_talents_on_hired_talents_job_id"
    t.index ["deleted_at", "last_invited_by_id"], name: "index_talents_on_deleted_at_and_last_invited_by_id"
    t.index ["deleted_at", "last_updated_by_id"], name: "index_talents_on_last_updated_by_id"
    t.index ["deleted_at", "matching_job_title_id"], name: "index_talents_on_matching_job_title_id"
    t.index ["deleted_at", "rtr_expire_job_id"], name: "index_talents_on_deleted_at_and_rtr_expire_job_id"
    t.index ["deleted_at", "timezone_id"], name: "index_talents_on_timezone_id"
    t.index ["deleted_at", "updated_by_id", "updated_by_type"], name: "index_talents_on_updated_by_id_and_updated_by_type"
    t.index ["id", "deleted_at"], name: "index_talents_on_id_and_deleted_at"
  end

  create_table "talents_jobs", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "stage"
    t.string "next_stage"
    t.boolean "viewed", default: false
    t.boolean "rejected", default: false
    t.string "invitation_token"
    t.text "reason_notes"
    t.text "reason_to_reinstate"
    t.text "reinstate_notes"
    t.boolean "withdrawn", default: false
    t.text "reason_to_withdrawn"
    t.text "withdrawn_notes"
    t.boolean "interested", default: false
    t.text "message"
    t.datetime "invitation_expire_at"
    t.datetime "invited_at"
    t.datetime "published_at"
    t.boolean "offline", default: false
    t.boolean "active", default: true
    t.uuid "job_id"
    t.uuid "talent_id"
    t.uuid "agency_id"
    t.uuid "user_id"
    t.string "rejected_by_type"
    t.uuid "rejected_by_id"
    t.string "reinstate_by_type"
    t.uuid "reinstate_by_id"
    t.string "withdrawn_by_type"
    t.uuid "withdrawn_by_id"
    t.uuid "profile_id"
    t.uuid "client_id"
    t.uuid "invited_talent_id"
    t.uuid "hiring_organization_id"
    t.uuid "billing_term_id"
    t.string "email"
    t.text "candidate_overview"
    t.string "shared_id"
    t.float "sort_order"
    t.boolean "offer_extend", default: false
    t.text "hold_offer_reason"
    t.string "primary_disqualify_reason"
    t.string "secondary_disqualify_reason"
    t.string "sentiment"
    t.datetime "rejected_at"
    t.datetime "withdrawn_at"
    t.index ["deleted_at", "active", "stage", "rejected", "withdrawn", "id"], name: "tj_active_stage_rejected_withdrawn"
    t.index ["deleted_at", "agency_id"], name: "index_talents_jobs_on_agency_id"
    t.index ["deleted_at", "billing_term_id"], name: "index_talents_jobs_on_billing_term_id"
    t.index ["deleted_at", "client_id"], name: "index_talents_jobs_on_client_id"
    t.index ["deleted_at", "hiring_organization_id"], name: "index_talents_jobs_on_hiring_organization_id"
    t.index ["deleted_at", "invited_talent_id"], name: "index_talents_jobs_on_invited_talent_id"
    t.index ["deleted_at", "job_id"], name: "index_talents_jobs_on_job_id"
    t.index ["deleted_at", "profile_id"], name: "index_talents_jobs_on_profile_id"
    t.index ["deleted_at", "reinstate_by_id", "reinstate_by_type"], name: "index_talents_jobs_on_reinstate_by_id_and_reinstate_by_type"
    t.index ["deleted_at", "rejected_by_id", "rejected_by_type"], name: "index_talents_jobs_on_rejected_by_id_and_rejected_by_type"
    t.index ["deleted_at", "talent_id"], name: "index_talents_jobs_on_talent_id"
    t.index ["deleted_at", "user_id"], name: "index_talents_jobs_on_user_id"
    t.index ["deleted_at", "withdrawn_by_id", "withdrawn_by_type"], name: "index_talents_jobs_on_withdrawn_by_id_and_withdrawn_by_type"
    t.index ["id", "deleted_at"], name: "index_talents_jobs_on_id_and_deleted_at"
  end

  create_table "talents_jobs_resumes", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "resume_id"
    t.uuid "talents_job_id"
    t.boolean "if_primary", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id"], name: "index_talents_jobs_resumes_on_resume_id"
    t.index ["talents_job_id"], name: "index_talents_jobs_resumes_on_talents_job_id"
  end

  create_table "teams", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "name"
    t.text "logo"
    t.boolean "image_resized", default: true
    t.string "country"
    t.string "state"
    t.boolean "enabled", default: true
    t.float "rate", default: 0.0
    t.float "member_rate", default: 0.0
    t.integer "users_count", default: 0
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.string "city"
    t.string "postal_code"
    t.string "company_name"
    t.text "summary"
    t.string "job_types", default: [], array: true
    t.uuid "agency_id"
    t.uuid "timezone_id"
    t.uuid "created_by_id"
    t.uuid "updated_by_id"
    t.string "logo_100_public"
    t.string "logo_50_public"
    t.datetime "locked_at"
    t.index ["deleted_at", "agency_id"], name: "index_teams_on_agency_id"
    t.index ["deleted_at", "created_by_id"], name: "index_teams_on_created_by_id"
    t.index ["deleted_at", "timezone_id"], name: "index_teams_on_timezone_id"
    t.index ["deleted_at", "updated_by_id"], name: "index_teams_on_updated_by_id"
    t.index ["id", "deleted_at"], name: "index_teams_on_id_and_deleted_at"
  end

  create_table "teams_users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "team_id"
    t.uuid "user_id"
    t.index ["team_id"], name: "index_teams_users_on_team_id"
    t.index ["user_id"], name: "index_teams_users_on_user_id"
  end

  create_table "templates", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "name"
    t.text "content"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_templates_on_user_id"
  end

  create_table "third_party_data", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.string "data"
    t.string "embeddable_type"
    t.string "uid"
    t.string "agency_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "embeddable_id"
    t.index ["embeddable_type", "embeddable_id"], name: "index_third_party_data_on_embeddable_type_and_embeddable_id"
  end

  create_table "time_slots", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "start_date_time"
    t.datetime "end_date_time"
    t.boolean "approved_by_talent", default: false
    t.uuid "event_id"
    t.uuid "timezone_id"
    t.index ["event_id"], name: "index_time_slots_on_event_id"
    t.index ["timezone_id"], name: "index_time_slots_on_timezone_id"
  end

  create_table "timezones", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.text "name"
    t.text "abbr"
    t.text "value"
    t.boolean "if_dst"
    t.text "dst_start_day"
    t.text "dst_end_day"
    t.boolean "truncated", default: false
    t.string "synonyms", default: [], array: true
  end

  create_table "to_messages_talents", id: false, force: :cascade do |t|
    t.uuid "message_id"
    t.uuid "talent_id"
    t.index ["message_id", "talent_id"], name: "index_to_messages_talents_on_message_id_and_talent_id"
    t.index ["message_id"], name: "index_to_messages_talents_on_message_id"
    t.index ["talent_id"], name: "index_to_messages_talents_on_talent_id"
  end

  create_table "to_messages_users", id: false, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "message_id"
    t.index ["message_id", "user_id"], name: "index_to_messages_users_on_message_id_and_user_id"
    t.index ["message_id"], name: "index_to_messages_users_on_message_id"
    t.index ["user_id"], name: "index_to_messages_users_on_user_id"
  end

  create_table "user_searches", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "search_tag"
    t.jsonb "filters"
    t.string "related_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "username"
    t.text "encrypted_password", default: ""
    t.text "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.boolean "password_set_by_user", default: false
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.text "current_sign_in_ip"
    t.text "last_sign_in_ip"
    t.text "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.text "unconfirmed_email"
    t.text "unlock_token"
    t.datetime "locked_at"
    t.text "address"
    t.text "city"
    t.text "state"
    t.text "country"
    t.text "postal_code"
    t.jsonb "country_obj"
    t.jsonb "state_obj"
    t.jsonb "city_obj"
    t.float "rate", default: 0.0
    t.boolean "can_submit_member_directly", default: false
    t.boolean "assign_phone", default: false
    t.text "first_name"
    t.text "last_name"
    t.text "middle_name"
    t.text "title"
    t.text "headline"
    t.text "avatar"
    t.boolean "image_resized", default: false
    t.integer "sin"
    t.text "email"
    t.text "contact_no"
    t.text "primary_role"
    t.integer "role_group"
    t.text "bio"
    t.boolean "confirmation_status", default: false
    t.boolean "viewed_invite", default: false
    t.string "job_types", default: [], array: true
    t.uuid "client_id"
    t.uuid "agency_id"
    t.uuid "created_by_id"
    t.uuid "updated_by_id"
    t.uuid "timezone_id"
    t.jsonb "custom_permissions", default: {}
    t.string "show_status"
    t.boolean "restrict_access", default: false
    t.boolean "tnc", default: false
    t.datetime "profile_tnc_accepted_at"
    t.uuid "hiring_organization_id"
    t.string "extension"
    t.string "avatar_100_public"
    t.string "avatar_50_public"
    t.text "email_signature"
    t.datetime "verified_at"
    t.index ["deleted_at", "agency_id"], name: "index_users_on_agency_id"
    t.index ["deleted_at", "client_id"], name: "index_users_on_client_id"
    t.index ["deleted_at", "confirmed_at", "locked_at"], name: "index_users_on_confirmed_at_and_locked_at"
    t.index ["deleted_at", "created_by_id"], name: "index_users_on_created_by_id"
    t.index ["deleted_at", "email"], name: "index_users_on_email"
    t.index ["deleted_at", "hiring_organization_id"], name: "index_users_on_deleted_at_and_hiring_organization_id"
    t.index ["deleted_at", "primary_role"], name: "index_users_on_deleted_at_and_primary_role"
    t.index ["deleted_at", "timezone_id"], name: "index_users_on_timezone_id"
    t.index ["deleted_at", "updated_by_id"], name: "index_users_on_updated_by_id"
    t.index ["hiring_organization_id"], name: "index_users_on_hiring_organization_id"
    t.index ["id", "deleted_at"], name: "index_users_on_id_and_deleted_at"
  end

  create_table "users_reminders", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "reminder_id"
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reminder_id"], name: "index_users_reminders_on_reminder_id"
    t.index ["user_id"], name: "index_users_reminders_on_user_id"
  end

  create_table "vendors", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.text "name"
  end

  create_table "views", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "job_id"
    t.uuid "agency_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "job_id"], name: "index_views_on_user_id_and_job_id"
  end

  create_table "vms_platforms", id: :uuid, default: -> { "uuid_generate_v4()" }, force: :cascade do |t|
    t.datetime "deleted_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "name"
  end

  create_table "yoyo_lock", primary_key: "locked", id: :integer, default: 1, force: :cascade do |t|
    t.datetime "ctime"
    t.integer "pid", null: false
  end

  add_foreign_key "accessibles", "agencies"
  add_foreign_key "accessibles", "billing_terms"
  add_foreign_key "accessibles", "clients"
  add_foreign_key "accessibles", "hiring_organizations"
  add_foreign_key "accessibles", "users", column: "created_by_id"
  add_foreign_key "acknowledge_disqualified_users", "talents_jobs"
  add_foreign_key "acknowledge_disqualified_users", "users"
  add_foreign_key "acknowledge_job_hold_users", "jobs"
  add_foreign_key "acknowledge_job_hold_users", "users"
  add_foreign_key "agencies", "users", column: "created_by_id"
  add_foreign_key "agencies", "users", column: "updated_by_id"
  add_foreign_key "assignment_details", "completed_transitions"
  add_foreign_key "assignment_details", "timezones"
  add_foreign_key "assignment_details", "users", column: "updated_by_id"
  add_foreign_key "badges", "jobs"
  add_foreign_key "badges", "users"
  add_foreign_key "bill_rate_negotiations", "bill_rate_negotiations", column: "proposed_bill_rate_id"
  add_foreign_key "bill_rate_negotiations", "rtrs"
  add_foreign_key "bill_rate_negotiations", "users", column: "approved_by_id"
  add_foreign_key "bill_rate_negotiations", "users", column: "proposed_by_id"
  add_foreign_key "bill_rate_negotiations", "users", column: "rejected_by_id"
  add_foreign_key "billing_terms", "ats_platforms"
  add_foreign_key "billing_terms", "clients"
  add_foreign_key "billing_terms", "hiring_organizations"
  add_foreign_key "billing_terms", "msp_names"
  add_foreign_key "billing_terms", "proprietary_platforms"
  add_foreign_key "billing_terms", "users", column: "created_by_id"
  add_foreign_key "billing_terms", "vms_platforms"
  add_foreign_key "certificates", "vendors"
  add_foreign_key "certifications", "certificates"
  add_foreign_key "certifications", "vendors"
  add_foreign_key "change_histories", "users"
  add_foreign_key "cities", "states"
  add_foreign_key "clients", "industries"
  add_foreign_key "clients", "timezones"
  add_foreign_key "clients", "users", column: "created_by_id"
  add_foreign_key "completed_transitions", "events"
  add_foreign_key "completed_transitions", "pipeline_steps"
  add_foreign_key "completed_transitions", "talents_jobs"
  add_foreign_key "contacts", "hiring_organizations"
  add_foreign_key "contacts", "timezones"
  add_foreign_key "contacts", "users"
  add_foreign_key "event_attendees", "events"
  add_foreign_key "events", "events", column: "parent_id"
  add_foreign_key "events", "users"
  add_foreign_key "favorites", "talents_jobs"
  add_foreign_key "favorites", "users"
  add_foreign_key "groups", "users", column: "created_by_id"
  add_foreign_key "hiring_organizations", "clients"
  add_foreign_key "hiring_organizations", "users", column: "created_by_id"
  add_foreign_key "ho_jobs_watchers", "jobs"
  add_foreign_key "ho_jobs_watchers", "users"
  add_foreign_key "identities", "talents"
  add_foreign_key "interview_slots", "talents"
  add_foreign_key "job_manual_invite_requests", "jobs"
  add_foreign_key "job_manual_invite_requests", "users"
  add_foreign_key "job_providers", "jobs"
  add_foreign_key "jobs", "billing_terms"
  add_foreign_key "jobs", "categories"
  add_foreign_key "jobs", "clients"
  add_foreign_key "jobs", "hiring_organizations"
  add_foreign_key "jobs", "industries"
  add_foreign_key "jobs", "timezones"
  add_foreign_key "jobs", "users", column: "account_manager_id"
  add_foreign_key "jobs", "users", column: "created_by_id"
  add_foreign_key "jobs", "users", column: "hiring_manager_id"
  add_foreign_key "jobs", "users", column: "onboarding_agent_id"
  add_foreign_key "jobs", "users", column: "published_by_id"
  add_foreign_key "jobs", "users", column: "supervisor_id"
  add_foreign_key "jobs", "users", column: "updated_by_id"
  add_foreign_key "mentioned_users", "talents_jobs"
  add_foreign_key "mentioned_users", "users"
  add_foreign_key "metrics_stages", "agencies"
  add_foreign_key "metrics_stages", "billing_terms"
  add_foreign_key "metrics_stages", "clients"
  add_foreign_key "metrics_stages", "hiring_organizations"
  add_foreign_key "metrics_stages", "jobs"
  add_foreign_key "metrics_stages", "talents_jobs"
  add_foreign_key "notes", "notes", column: "parent_id"
  add_foreign_key "notes", "users"
  add_foreign_key "notifications", "agencies"
  add_foreign_key "offer_letters", "completed_transitions"
  add_foreign_key "offer_letters", "timezones"
  add_foreign_key "offer_letters", "users", column: "updated_by_id"
  add_foreign_key "onboarding_documents", "onboarding_packages"
  add_foreign_key "onboarding_packages", "users", column: "created_by_id"
  add_foreign_key "onboards", "onboarding_documents"
  add_foreign_key "onboards", "talents_jobs"
  add_foreign_key "pipeline_notifications", "talents_jobs"
  add_foreign_key "pipeline_notifications", "users", column: "created_by_id"
  add_foreign_key "pipeline_steps", "recruitment_pipelines"
  add_foreign_key "potential_earnings", "jobs"
  add_foreign_key "potential_earnings", "users"
  add_foreign_key "profiles", "hiring_organizations"
  add_foreign_key "profiles", "matching_job_titles"
  add_foreign_key "questions", "questionnaires"
  add_foreign_key "questions", "users"
  add_foreign_key "questions_templates", "questions"
  add_foreign_key "questions_templates", "templates"
  add_foreign_key "receivers", "messages"
  add_foreign_key "recruitment_pipelines", "users", column: "created_by_id"
  add_foreign_key "recruitment_pipelines", "users", column: "updated_by_id"
  add_foreign_key "rejected_histories", "clients"
  add_foreign_key "rejected_histories", "onboards"
  add_foreign_key "reminders", "users", column: "created_by_id"
  add_foreign_key "rtrs", "completed_transitions"
  add_foreign_key "rtrs", "timezones"
  add_foreign_key "shareables", "jobs"
  add_foreign_key "shareables", "share_links"
  add_foreign_key "shareables", "talents"
  add_foreign_key "shareables", "users"
  add_foreign_key "sourced_for_jobs", "talents"
  add_foreign_key "states", "countries"
  add_foreign_key "taggings", "tags"
  add_foreign_key "talents", "matching_job_titles"
  add_foreign_key "talents_jobs", "agencies"
  add_foreign_key "talents_jobs", "billing_terms"
  add_foreign_key "talents_jobs", "clients"
  add_foreign_key "talents_jobs", "hiring_organizations"
  add_foreign_key "talents_jobs", "jobs"
  add_foreign_key "talents_jobs", "profiles"
  add_foreign_key "talents_jobs", "talents"
  add_foreign_key "talents_jobs", "talents", column: "invited_talent_id"
  add_foreign_key "talents_jobs", "users"
  add_foreign_key "teams", "agencies"
  add_foreign_key "teams", "timezones"
  add_foreign_key "teams", "users", column: "created_by_id"
  add_foreign_key "teams", "users", column: "updated_by_id"
  add_foreign_key "templates", "users"
  add_foreign_key "time_slots", "events"
  add_foreign_key "users", "clients"
  add_foreign_key "users", "timezones"
  add_foreign_key "users_reminders", "reminders"
  add_foreign_key "users_reminders", "users"
end
