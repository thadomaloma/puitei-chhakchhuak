class CreateBillingAndPayments < ActiveRecord::Migration[8.1]
  def up
    add_column :order_items, :unit_price, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_check_constraint :order_items, "unit_price >= 0", name: "order_items_unit_price_nonnegative"

    add_column :orders, :currency, :string, null: false, default: "INR"
    add_column :orders, :subtotal_amount, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :orders, :discount_amount, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :orders, :tax_rate_snapshot, :decimal, precision: 5, scale: 2, null: false, default: 0
    add_column :orders, :tax_amount, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :orders, :total_amount, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :orders, :pricing_finalized_at, :datetime
    add_check_constraint :orders,
      "subtotal_amount >= 0 AND discount_amount >= 0 AND discount_amount <= subtotal_amount AND tax_amount >= 0 AND total_amount >= 0",
      name: "orders_amounts_nonnegative"
    add_check_constraint :orders, "tax_rate_snapshot >= 0 AND tax_rate_snapshot <= 100", name: "orders_tax_rate_range"

    create_table :payments do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true
      t.references :received_by, null: false, foreign_key: { to_table: :users }
      t.references :voided_by, foreign_key: { to_table: :users }
      t.string :payment_number, null: false
      t.integer :sequence_year, null: false
      t.integer :sequence_number, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :payment_method, null: false, default: 0
      t.date :paid_on, null: false
      t.string :reference_number
      t.text :notes
      t.datetime :voided_at
      t.text :void_reason
      t.timestamps
    end

    add_index :payments, :payment_number, unique: true
    add_index :payments, [ :branch_id, :sequence_year, :sequence_number ], unique: true, name: "index_payments_on_branch_year_and_sequence"
    add_index :payments, [ :order_id, :voided_at, :paid_on ]
    add_check_constraint :payments, "amount > 0", name: "payments_amount_positive"
    add_check_constraint :payments, "sequence_number > 0", name: "payments_sequence_positive"
    add_check_constraint :payments, "sequence_year >= 2000", name: "payments_sequence_year"
    add_check_constraint :payments, "payment_method >= 0 AND payment_method <= 4", name: "payments_method_range"
    add_check_constraint :payments,
      "(voided_at IS NULL AND voided_by_id IS NULL AND void_reason IS NULL) OR (voided_at IS NOT NULL AND voided_by_id IS NOT NULL AND length(trim(void_reason)) > 0)",
      name: "payments_void_complete"
  end

  def down
    drop_table :payments
    remove_check_constraint :orders, name: "orders_tax_rate_range"
    remove_check_constraint :orders, name: "orders_amounts_nonnegative"
    remove_columns :orders, :currency, :subtotal_amount, :discount_amount, :tax_rate_snapshot, :tax_amount, :total_amount, :pricing_finalized_at
    remove_check_constraint :order_items, name: "order_items_unit_price_nonnegative"
    remove_column :order_items, :unit_price
  end
end
