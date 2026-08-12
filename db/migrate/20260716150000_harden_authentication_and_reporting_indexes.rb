class HardenAuthenticationAndReportingIndexes < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
    add_index :users, :locked_at

    remove_index :attendance_records, name: "index_attendance_records_on_user_id_and_work_date"
    add_index :attendance_records, %i[shop_id user_id work_date], unique: true,
      name: "index_attendance_on_shop_user_and_work_date"

    add_index :attendance_records, %i[shop_id work_date],
      name: "index_attendance_records_on_shop_and_work_date"
    add_index :customers, %i[shop_id created_at], name: "index_customers_on_shop_and_created_at"
    add_index :deliveries, %i[shop_id handed_over_at], name: "index_deliveries_on_shop_and_handed_over_at"
    add_index :expenses, %i[shop_id approval_status voided_at incurred_on],
      name: "index_expenses_on_shop_status_and_incurred_on"
    add_index :orders, %i[shop_id status ordered_on], name: "index_orders_on_shop_status_and_ordered_on"
  end
end
