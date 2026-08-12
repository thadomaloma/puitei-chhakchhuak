class CreateStaffWorkforceManagement < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :employee_code, :string
    add_column :users, :phone_number, :string
    add_column :users, :job_title, :string
    add_column :users, :joined_on, :date
    add_column :users, :pay_basis, :integer, null: false, default: 0
    add_column :users, :pay_rate, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :users, :emergency_contact, :string

    execute <<~SQL.squish
      UPDATE users
      SET employee_code = 'STF-' || branches.code || '-' || LPAD(users.id::text, 4, '0'),
          joined_on = users.created_at::date
      FROM branches
      WHERE users.branch_id = branches.id
    SQL

    change_column_null :users, :employee_code, false
    change_column_null :users, :joined_on, false
    add_index :users, :employee_code, unique: true
    add_index :users, [ :branch_id, :active, :name ]
    add_check_constraint :users, "employee_code ~ '^STF-[A-Z0-9_-]+-[0-9]{4,}$'", name: "users_employee_code_format"
    add_check_constraint :users, "pay_basis >= 0 AND pay_basis <= 3", name: "users_pay_basis_range"
    add_check_constraint :users, "pay_rate >= 0", name: "users_pay_rate_nonnegative"

    create_table :staff_events do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :staff_member, null: false, foreign_key: { to_table: :users }
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.jsonb :details, null: false, default: {}
      t.datetime :happened_at, null: false
      t.timestamps
    end
    add_index :staff_events, [ :staff_member_id, :happened_at ]
    add_index :staff_events, [ :branch_id, :event_type, :happened_at ]
    add_check_constraint :staff_events, "length(trim(event_type)) > 0", name: "staff_events_type_present"

    create_table :attendance_records do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :work_date, null: false
      t.datetime :checked_in_at, null: false
      t.datetime :checked_out_at
      t.text :notes
      t.timestamps
    end
    add_index :attendance_records, [ :user_id, :work_date ], unique: true
    add_index :attendance_records, [ :branch_id, :work_date ]
    add_check_constraint :attendance_records,
      "checked_out_at IS NULL OR checked_out_at > checked_in_at", name: "attendance_checkout_after_checkin"

    create_table :leave_requests do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.integer :leave_type, null: false, default: 0
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.text :reason, null: false
      t.integer :status, null: false, default: 0
      t.datetime :reviewed_at
      t.text :review_notes
      t.timestamps
    end
    add_index :leave_requests, [ :branch_id, :status, :starts_on ]
    add_index :leave_requests, [ :user_id, :starts_on ]
    add_check_constraint :leave_requests, "leave_type >= 0 AND leave_type <= 4", name: "leave_requests_type_range"
    add_check_constraint :leave_requests, "status >= 0 AND status <= 3", name: "leave_requests_status_range"
    add_check_constraint :leave_requests, "ends_on >= starts_on", name: "leave_requests_dates_valid"
    add_check_constraint :leave_requests, "length(trim(reason)) > 0", name: "leave_requests_reason_present"
    add_check_constraint :leave_requests,
      "(status IN (0, 3) AND reviewed_at IS NULL AND reviewed_by_id IS NULL) OR (status IN (1, 2) AND reviewed_at IS NOT NULL AND reviewed_by_id IS NOT NULL)",
      name: "leave_requests_review_consistent"

    create_table :work_shifts do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :cancelled_by, foreign_key: { to_table: :users }
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :location
      t.text :notes
      t.datetime :cancelled_at
      t.text :cancel_reason
      t.timestamps
    end
    add_index :work_shifts, [ :branch_id, :starts_at ]
    add_index :work_shifts, [ :user_id, :starts_at ]
    add_check_constraint :work_shifts, "ends_at > starts_at", name: "work_shifts_dates_valid"
    add_check_constraint :work_shifts,
      "(cancelled_at IS NULL AND cancelled_by_id IS NULL AND cancel_reason IS NULL) OR (cancelled_at IS NOT NULL AND cancelled_by_id IS NOT NULL AND length(trim(cancel_reason)) > 0)",
      name: "work_shifts_cancellation_consistent"
  end

  def down
    drop_table :work_shifts
    drop_table :leave_requests
    drop_table :attendance_records
    drop_table :staff_events
    remove_column :users, :emergency_contact
    remove_column :users, :pay_rate
    remove_column :users, :pay_basis
    remove_column :users, :joined_on
    remove_column :users, :job_title
    remove_column :users, :phone_number
    remove_column :users, :employee_code
  end
end
