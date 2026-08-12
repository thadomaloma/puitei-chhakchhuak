class CreateDeliveryHandover < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :orders, name: "orders_status_range"
    add_check_constraint :orders, "status >= 0 AND status <= 3", name: "orders_status_range"

    create_table :deliveries do |t|
      t.references :branch, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :delivered_by, null: false, foreign_key: { to_table: :users }
      t.string :delivery_number, null: false
      t.integer :sequence_year, null: false
      t.integer :sequence_number, null: false
      t.datetime :handed_over_at, null: false
      t.string :recipient_name, null: false
      t.string :recipient_phone
      t.integer :collection_method, null: false, default: 0
      t.string :recipient_relationship
      t.string :acknowledged_by, null: false
      t.boolean :recipient_acknowledged, null: false, default: false
      t.boolean :quality_checked, null: false, default: false
      t.boolean :garment_count_verified, null: false, default: false
      t.boolean :payment_status_confirmed, null: false, default: false
      t.boolean :packaging_complete, null: false, default: false
      t.decimal :total_amount_snapshot, precision: 12, scale: 2, null: false
      t.decimal :paid_amount_snapshot, precision: 12, scale: 2, null: false
      t.decimal :balance_due_snapshot, precision: 12, scale: 2, null: false
      t.string :currency, null: false
      t.text :notes
      t.timestamps
    end

    add_index :deliveries, :delivery_number, unique: true
    add_index :deliveries, [ :branch_id, :sequence_year, :sequence_number ], unique: true, name: "index_deliveries_on_branch_year_and_sequence"
    add_index :deliveries, [ :branch_id, :handed_over_at ]
    add_check_constraint :deliveries, "sequence_number > 0", name: "deliveries_sequence_positive"
    add_check_constraint :deliveries, "sequence_year >= 2000", name: "deliveries_sequence_year"
    add_check_constraint :deliveries, "collection_method >= 0 AND collection_method <= 2", name: "deliveries_collection_method_range"
    add_check_constraint :deliveries,
      "total_amount_snapshot >= 0 AND paid_amount_snapshot >= 0 AND balance_due_snapshot >= 0 AND paid_amount_snapshot + balance_due_snapshot <= total_amount_snapshot",
      name: "deliveries_amounts_valid"
    add_check_constraint :deliveries,
      "quality_checked AND garment_count_verified AND payment_status_confirmed AND packaging_complete AND recipient_acknowledged",
      name: "deliveries_checklist_complete"
    add_check_constraint :deliveries, "length(trim(recipient_name)) > 0 AND length(trim(acknowledged_by)) > 0", name: "deliveries_recipient_present"
  end

  def down
    drop_table :deliveries
    remove_check_constraint :orders, name: "orders_status_range"
    add_check_constraint :orders, "status >= 0 AND status <= 2", name: "orders_status_range"
  end
end
