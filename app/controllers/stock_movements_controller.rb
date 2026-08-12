class StockMovementsController < ApplicationController
  def create
    item = policy_scope(InventoryItem).find(stock_movement_params[:inventory_item_id])
    order_item = find_order_item(stock_movement_params[:order_item_id])
    type = stock_movement_params[:movement_type]
    movement = item.stock_movements.new(
      actor: current_user, order_item: order_item,
      movement_type: (StockMovement.movement_types.key?(type) ? type : "stock_in"),
      quantity: stock_movement_params[:quantity], happened_on: stock_movement_params[:happened_on],
      reference: stock_movement_params[:reference], notes: stock_movement_params[:notes]
    )
    authorize movement
    raise InventoryItem::InvalidMovement, "Unknown stock movement" unless StockMovement.movement_types.key?(type)

    item.record_movement!(
      movement_type: movement.movement_type, quantity: movement.quantity, actor: current_user,
      order_item: order_item, happened_on: movement.happened_on, reference: movement.reference, notes: movement.notes
    )
    redirect_to destination_for(item, order_item), notice: t("inventory.movement_created")
  rescue InventoryItem::InvalidMovement, ActiveRecord::RecordInvalid => error
    redirect_to(destination_for(item, order_item), alert: error.message)
  end

  private

  def stock_movement_params
    params.require(:stock_movement).permit(
      :inventory_item_id, :order_item_id, :movement_type, :quantity, :happened_on, :reference, :notes, :return_to
    )
  end

  def find_order_item(id)
    return if id.blank?

    OrderItem.joins(:order).merge(policy_scope(Order)).find(id)
  end

  def destination_for(item, order_item)
    stock_movement_params[:return_to] == "order" && order_item ? order_path(order_item.order) : inventory_item_path(item)
  end
end
