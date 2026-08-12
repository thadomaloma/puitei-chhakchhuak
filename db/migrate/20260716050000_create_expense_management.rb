class CreateExpenseManagement < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, foreign_key: { to_table: :users }
      t.references :voided_by, foreign_key: { to_table: :users }
      t.references :source_expense, foreign_key: { to_table: :expenses }
      t.string :expense_number, null: false
      t.integer :sequence_year, null: false
      t.integer :sequence_number, null: false
      t.integer :category, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false
      t.date :incurred_on, null: false
      t.string :vendor
      t.integer :payment_method, null: false, default: 0
      t.string :reference_number
      t.string :description, null: false
      t.text :notes
      t.integer :approval_status, null: false, default: 0
      t.datetime :approved_at
      t.datetime :voided_at
      t.text :void_reason
      t.integer :recurrence_interval, null: false, default: 0
      t.date :next_due_on
      t.timestamps
    end

    add_index :expenses, :expense_number, unique: true
    add_index :expenses, [ :branch_id, :sequence_year, :sequence_number ], unique: true, name: "index_expenses_on_branch_year_and_sequence"
    add_index :expenses, [ :branch_id, :incurred_on ]
    add_index :expenses, [ :branch_id, :approval_status, :voided_at ]
    add_index :expenses, [ :branch_id, :category ]
    add_check_constraint :expenses, "sequence_number > 0", name: "expenses_sequence_positive"
    add_check_constraint :expenses, "sequence_year >= 2000", name: "expenses_sequence_year"
    add_check_constraint :expenses, "amount > 0", name: "expenses_amount_positive"
    add_check_constraint :expenses, "category >= 0 AND category <= 9", name: "expenses_category_range"
    add_check_constraint :expenses, "payment_method >= 0 AND payment_method <= 4", name: "expenses_payment_method_range"
    add_check_constraint :expenses, "approval_status >= 0 AND approval_status <= 1", name: "expenses_approval_status_range"
    add_check_constraint :expenses, "recurrence_interval >= 0 AND recurrence_interval <= 4", name: "expenses_recurrence_range"
    add_check_constraint :expenses, "length(trim(description)) > 0", name: "expenses_description_present"
    add_check_constraint :expenses,
      "(approval_status = 0 AND approved_at IS NULL AND approved_by_id IS NULL) OR (approval_status = 1 AND approved_at IS NOT NULL AND approved_by_id IS NOT NULL)",
      name: "expenses_approval_consistent"
    add_check_constraint :expenses,
      "(voided_at IS NULL AND voided_by_id IS NULL AND void_reason IS NULL) OR (voided_at IS NOT NULL AND voided_by_id IS NOT NULL AND length(trim(void_reason)) > 0)",
      name: "expenses_void_consistent"
    add_check_constraint :expenses,
      "(recurrence_interval = 0 AND next_due_on IS NULL) OR (recurrence_interval > 0 AND next_due_on IS NOT NULL AND next_due_on > incurred_on)",
      name: "expenses_recurrence_consistent"
  end
end
