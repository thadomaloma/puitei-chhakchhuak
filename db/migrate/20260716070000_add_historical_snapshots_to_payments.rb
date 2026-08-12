class AddHistoricalSnapshotsToPayments < ActiveRecord::Migration[8.1]
  def up
    add_column :payments, :order_total_snapshot, :decimal, precision: 12, scale: 2
    add_column :payments, :balance_before_snapshot, :decimal, precision: 12, scale: 2
    add_column :payments, :balance_after_snapshot, :decimal, precision: 12, scale: 2
    add_column :payments, :currency_snapshot, :string

    execute <<~SQL.squish
      UPDATE payments AS payment
      SET order_total_snapshot = orders.total_amount,
          currency_snapshot = orders.currency,
          balance_before_snapshot = GREATEST(
            orders.total_amount - COALESCE((
              SELECT SUM(previous.amount)
              FROM payments AS previous
              WHERE previous.order_id = payment.order_id
                AND (previous.created_at < payment.created_at OR (previous.created_at = payment.created_at AND previous.id < payment.id))
                AND (previous.voided_at IS NULL OR previous.voided_at > payment.created_at)
            ), 0),
            0
          ),
          balance_after_snapshot = GREATEST(
            orders.total_amount - COALESCE((
              SELECT SUM(previous.amount)
              FROM payments AS previous
              WHERE previous.order_id = payment.order_id
                AND (previous.created_at < payment.created_at OR (previous.created_at = payment.created_at AND previous.id < payment.id))
                AND (previous.voided_at IS NULL OR previous.voided_at > payment.created_at)
            ), 0) - payment.amount,
            0
          )
      FROM orders
      WHERE orders.id = payment.order_id
    SQL

    change_column_null :payments, :order_total_snapshot, false
    change_column_null :payments, :balance_before_snapshot, false
    change_column_null :payments, :balance_after_snapshot, false
    change_column_null :payments, :currency_snapshot, false

    add_check_constraint :payments,
      "order_total_snapshot >= 0 AND balance_before_snapshot >= 0 AND balance_after_snapshot >= 0 AND balance_after_snapshot <= balance_before_snapshot",
      name: "payments_snapshots_nonnegative"
    add_check_constraint :payments,
      "balance_before_snapshot - amount = balance_after_snapshot",
      name: "payments_snapshot_amount_matches"
  end

  def down
    remove_check_constraint :payments, name: "payments_snapshot_amount_matches"
    remove_check_constraint :payments, name: "payments_snapshots_nonnegative"
    remove_columns :payments, :order_total_snapshot, :balance_before_snapshot, :balance_after_snapshot, :currency_snapshot
  end
end
