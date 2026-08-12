class InventoryItemsController < ApplicationController
  before_action :set_inventory_item, only: %i[show edit update archive]

  def index
    authorize InventoryItem
    items = policy_scope(InventoryItem).search(params[:query])
    items = items.where(active: true) unless params[:archived] == "1"
    items = items.where(category: params[:category]) if InventoryItem.categories.key?(params[:category])
    items = filter_by_stock(items)
    @filtered_count = items.count
    @filters_active = params.values_at(:query, :category, :stock).any?(&:present?) || params[:archived] == "1"
    @pagy, @inventory_items = pagy(:offset, items.alphabetical.with_attached_image, limit: 24)

    scoped = policy_scope(InventoryItem).active
    @item_count = scoped.count
    @low_stock_count = scoped.low_stock.count
    @reserved_count = scoped.where("quantity_reserved > 0").count
    @stock_value = scoped.sum("quantity_on_hand * cost_price")
    @out_of_stock_count = scoped.where("quantity_on_hand - quantity_reserved = 0").count
  end

  def show
    authorize @inventory_item
    movements = @inventory_item.stock_movements.includes(:actor, order_item: { order: :customer }).recent_first
    movements = movements.where(movement_type: params[:movement_type]) if StockMovement.movement_types.key?(params[:movement_type])
    @movement_count = movements.count
    @pagy, @stock_movements = pagy(:offset, movements, limit: 25)
    @active_reservations = active_reservations_for(@inventory_item)
    @movement_types = StockMovement.movement_types.keys.excluding("reservation", "release", "consumption").select do |type|
      policy(StockMovement.new(inventory_item: @inventory_item, movement_type: type)).create?
    end
  end

  def new
    @inventory_item = current_branch.inventory_items.new(reorder_level: current_branch.shop_setting.low_stock_threshold)
    authorize @inventory_item
  end

  def create
    @inventory_item = current_branch.inventory_items.new(inventory_item_params)
    authorize @inventory_item
    if @inventory_item.save
      redirect_to @inventory_item, notice: t("inventory.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @inventory_item
  end

  def update
    authorize @inventory_item
    if @inventory_item.update(inventory_item_params)
      if params.dig(:inventory_item, :remove_image) == "1" && params.dig(:inventory_item, :image).blank? && @inventory_item.image.attached?
        @inventory_item.image.purge
      end
      redirect_to @inventory_item, notice: t("inventory.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def archive
    authorize @inventory_item, :archive?
    @inventory_item.update!(active: false)
    redirect_to inventory_items_path, notice: t("inventory.archived")
  end

  private

  def set_inventory_item
    @inventory_item = policy_scope(InventoryItem).with_attached_image.find(params[:id])
  end

  def inventory_item_params
    params.require(:inventory_item).permit(
      :name, :sku, :category, :unit, :color, :supplier_name, :supplier_contact,
      :cost_price, :selling_price, :reorder_level, :notes, :image, :remove_image
    )
  end

  def active_reservations_for(item)
    deltas = item.stock_movements
      .reorder(nil)
      .where.not(order_item_id: nil)
      .where(movement_type: %i[reservation release consumption])
      .group(:order_item_id)
      .sum("CASE movement_type WHEN 5 THEN quantity WHEN 6 THEN -quantity WHEN 7 THEN -quantity ELSE 0 END")
      .select { |_order_item_id, quantity| quantity.positive? }
    order_items = OrderItem.includes(order: :customer).where(id: deltas.keys).index_by(&:id)

    deltas.filter_map { |order_item_id, quantity| [ order_items[order_item_id], quantity ] if order_items[order_item_id] }
  end

  def filter_by_stock(items)
    case params[:stock]
    when "out"
      items.where("quantity_on_hand - quantity_reserved = 0")
    when "low"
      items.where("quantity_on_hand - quantity_reserved > 0 AND quantity_on_hand - quantity_reserved <= reorder_level")
    when "available"
      items.where("quantity_on_hand - quantity_reserved > reorder_level")
    when "reserved"
      items.where("quantity_reserved > 0")
    else
      items
    end
  end
end
