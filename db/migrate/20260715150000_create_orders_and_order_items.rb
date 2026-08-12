class CreateOrdersAndOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :order_number, null: false
      t.integer :sequence_year, null: false
      t.integer :sequence_number, null: false
      t.integer :status, null: false, default: 0
      t.date :ordered_on, null: false
      t.date :trial_date
      t.date :delivery_date, null: false
      t.text :notes
      t.datetime :confirmed_at
      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, [ :branch_id, :sequence_year, :sequence_number ], unique: true, name: "index_orders_on_branch_year_and_sequence"
    add_index :orders, [ :branch_id, :status, :delivery_date ]
    add_check_constraint :orders, "sequence_number > 0", name: "orders_sequence_positive"
    add_check_constraint :orders, "sequence_year >= 2000", name: "orders_sequence_year"
    add_check_constraint :orders, "status >= 0 AND status <= 2", name: "orders_status_range"
    add_check_constraint :orders, "delivery_date >= ordered_on", name: "orders_delivery_after_order"
    add_check_constraint :orders, "trial_date IS NULL OR (trial_date >= ordered_on AND trial_date <= delivery_date)", name: "orders_trial_between_dates"

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :measurement, null: false, foreign_key: true
      t.string :garment_name, null: false
      t.integer :quantity, null: false, default: 1
      t.text :special_instructions
      t.jsonb :measurement_snapshot, null: false, default: {}
      t.timestamps
    end

    add_index :order_items, [ :order_id, :id ]
    add_check_constraint :order_items, "quantity > 0 AND quantity <= 100", name: "order_items_quantity_range"
    add_check_constraint :order_items, "jsonb_typeof(measurement_snapshot) = 'object'", name: "order_items_snapshot_object"
    add_check_constraint :order_items, "length(trim(garment_name)) > 0", name: "order_items_garment_name_present"
  end
end
