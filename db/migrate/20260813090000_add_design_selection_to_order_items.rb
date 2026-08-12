class AddDesignSelectionToOrderItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :order_items, :design_selection, foreign_key: true, null: true
  end
end
