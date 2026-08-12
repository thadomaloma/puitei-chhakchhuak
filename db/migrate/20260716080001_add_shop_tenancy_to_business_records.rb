class AddShopTenancyToBusinessRecords < ActiveRecord::Migration[8.1]
  DIRECT_TABLES = %i[
    customers deliveries expenses inventory_items leave_requests orders payments shop_settings
    staff_events attendance_records work_shifts
  ].freeze

  INDIRECT_SOURCES = {
    measurement_profiles: "customers",
    measurements: "measurement_profiles",
    order_items: "orders",
    production_tasks: "order_items",
    production_events: "production_tasks",
    stock_movements: "inventory_items"
  }.freeze

  GLOBAL_IDENTIFIERS = {
    customers: :customer_code,
    orders: :order_number,
    payments: :payment_number,
    deliveries: :delivery_number,
    expenses: :expense_number
  }.freeze

  def up
    (DIRECT_TABLES + INDIRECT_SOURCES.keys).each do |table|
      add_reference table, :shop, foreign_key: true
    end

    DIRECT_TABLES.each do |table|
      execute <<~SQL.squish
        UPDATE #{table}
        SET shop_id = branches.shop_id
        FROM branches
        WHERE branches.id = #{table}.branch_id
      SQL
    end

    backfill_indirect_tables

    (DIRECT_TABLES + INDIRECT_SOURCES.keys).each do |table|
      change_column_null table, :shop_id, false
    end

    GLOBAL_IDENTIFIERS.each do |table, column|
      remove_index table, column
      add_index table, [ :shop_id, column ], unique: true
    end

    add_index :customers, [ :shop_id, :phone_number ]
    add_index :orders, [ :shop_id, :status, :delivery_date ]
    add_index :payments, [ :shop_id, :paid_on, :voided_at ]
    add_index :inventory_items, [ :shop_id, :active, :category ]
    add_index :stock_movements, [ :shop_id, :created_at ]
    add_index :measurements, [ :shop_id, :measured_on ]
    add_index :production_tasks, [ :shop_id, :status, :stage ]
  end

  def down
    remove_index :production_tasks, [ :shop_id, :status, :stage ]
    remove_index :measurements, [ :shop_id, :measured_on ]
    remove_index :stock_movements, [ :shop_id, :created_at ]
    remove_index :inventory_items, [ :shop_id, :active, :category ]
    remove_index :payments, [ :shop_id, :paid_on, :voided_at ]
    remove_index :orders, [ :shop_id, :status, :delivery_date ]
    remove_index :customers, [ :shop_id, :phone_number ]

    GLOBAL_IDENTIFIERS.each do |table, column|
      remove_index table, [ :shop_id, column ]
      add_index table, column, unique: true
    end

    (DIRECT_TABLES + INDIRECT_SOURCES.keys).reverse_each do |table|
      remove_reference table, :shop, foreign_key: true
    end
  end

  private

  def backfill_indirect_tables
    execute <<~SQL.squish
      UPDATE measurement_profiles SET shop_id = customers.shop_id FROM customers
      WHERE customers.id = measurement_profiles.customer_id
    SQL
    execute <<~SQL.squish
      UPDATE measurements SET shop_id = measurement_profiles.shop_id FROM measurement_profiles
      WHERE measurement_profiles.id = measurements.measurement_profile_id
    SQL
    execute <<~SQL.squish
      UPDATE order_items SET shop_id = orders.shop_id FROM orders WHERE orders.id = order_items.order_id
    SQL
    execute <<~SQL.squish
      UPDATE production_tasks SET shop_id = order_items.shop_id FROM order_items
      WHERE order_items.id = production_tasks.order_item_id
    SQL
    execute <<~SQL.squish
      UPDATE production_events SET shop_id = production_tasks.shop_id FROM production_tasks
      WHERE production_tasks.id = production_events.production_task_id
    SQL
    execute <<~SQL.squish
      UPDATE stock_movements SET shop_id = inventory_items.shop_id FROM inventory_items
      WHERE inventory_items.id = stock_movements.inventory_item_id
    SQL
  end
end
