class AddTrialDateIndexToOrders < ActiveRecord::Migration[8.1]
  def change
    add_index :orders, [ :branch_id, :status, :trial_date ], name: "index_orders_on_branch_id_and_status_and_trial_date"
  end
end
