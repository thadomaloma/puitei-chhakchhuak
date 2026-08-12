class AllowDraftOrderDiscounts < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :orders, name: "orders_amounts_nonnegative"
    add_check_constraint :orders,
      "subtotal_amount >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND total_amount >= 0 AND (pricing_finalized_at IS NULL OR discount_amount <= subtotal_amount)",
      name: "orders_amounts_nonnegative"
  end
end
