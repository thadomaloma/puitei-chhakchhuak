class CreateInventoryManagement < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_items do |t|
      t.references :branch, null: false, foreign_key: true
      t.string :name, null: false
      t.string :sku, null: false
      t.integer :category, null: false, default: 0
      t.integer :unit, null: false, default: 0
      t.string :color
      t.string :supplier_name
      t.string :supplier_contact
      t.decimal :cost_price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :selling_price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :quantity_on_hand, precision: 12, scale: 3, null: false, default: 0
      t.decimal :quantity_reserved, precision: 12, scale: 3, null: false, default: 0
      t.decimal :reorder_level, precision: 12, scale: 3, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.text :notes
      t.timestamps
    end

    add_index :inventory_items, [ :branch_id, :sku ], unique: true
    add_index :inventory_items, [ :branch_id, :active, :category ]
    add_index :inventory_items, "lower(name)", name: "index_inventory_items_on_lower_name"
    add_check_constraint :inventory_items, "length(trim(name)) > 0", name: "inventory_items_name_present"
    add_check_constraint :inventory_items, "sku ~ '^[A-Z0-9_-]+$'", name: "inventory_items_sku_format"
    add_check_constraint :inventory_items, "category >= 0 AND category <= 7", name: "inventory_items_category_range"
    add_check_constraint :inventory_items, "unit >= 0 AND unit <= 6", name: "inventory_items_unit_range"
    add_check_constraint :inventory_items,
      "cost_price >= 0 AND selling_price >= 0 AND quantity_on_hand >= 0 AND quantity_reserved >= 0 AND reorder_level >= 0 AND quantity_reserved <= quantity_on_hand",
      name: "inventory_items_nonnegative_values"

    create_table :stock_movements do |t|
      t.references :inventory_item, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :order_item, foreign_key: true
      t.integer :movement_type, null: false
      t.decimal :quantity, precision: 12, scale: 3, null: false
      t.decimal :on_hand_before, precision: 12, scale: 3, null: false
      t.decimal :on_hand_after, precision: 12, scale: 3, null: false
      t.decimal :reserved_before, precision: 12, scale: 3, null: false
      t.decimal :reserved_after, precision: 12, scale: 3, null: false
      t.date :happened_on, null: false
      t.string :reference
      t.text :notes
      t.timestamps
    end

    add_index :stock_movements, [ :inventory_item_id, :created_at ]
    add_index :stock_movements, [ :order_item_id, :created_at ]
    add_check_constraint :stock_movements, "movement_type >= 0 AND movement_type <= 7", name: "stock_movements_type_range"
    add_check_constraint :stock_movements, "quantity > 0", name: "stock_movements_quantity_positive"
    add_check_constraint :stock_movements,
      "on_hand_before >= 0 AND on_hand_after >= 0 AND reserved_before >= 0 AND reserved_after >= 0 AND reserved_before <= on_hand_before AND reserved_after <= on_hand_after",
      name: "stock_movements_valid_balances"
  end
end
