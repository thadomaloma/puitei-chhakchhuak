require "test_helper"

class InventoryItemTest < ActiveSupport::TestCase
  setup do
    @item = inventory_items(:silk)
    @manager = users(:manager)
  end

  test "normalizes SKU and enforces branch uniqueness" do
    item = InventoryItem.new(
      branch: branches(:main), name: "Test fabric", sku: " test-001 ", category: :fabric,
      unit: :metre, cost_price: 10, selling_price: 12, reorder_level: 2
    )

    assert item.save
    assert_equal "TEST-001", item.sku

    duplicate = item.dup
    duplicate.name = "Duplicate"
    assert_not duplicate.valid?
    assert duplicate.errors[:sku].any?
  end

  test "records immutable stock movements and maintains atomic balances" do
    movement = @item.record_movement!(
      movement_type: :stock_in, quantity: 5.5, actor: @manager,
      reference: "INV-10", notes: "New delivery"
    )

    assert_equal 25.5.to_d, @item.reload.quantity_on_hand
    assert_equal 20.to_d, movement.on_hand_before
    assert_equal 25.5.to_d, movement.on_hand_after
    assert_not movement.update(quantity: 7)
    assert_not movement.destroy
    assert StockMovement.exists?(movement.id)
    assert_not @item.update(quantity_on_hand: 99)
    assert_equal 25.5.to_d, @item.reload.quantity_on_hand
  end

  test "reserves releases and consumes stock against a confirmed garment" do
    order = confirmed_order
    garment = order.order_items.first

    @item.record_movement!(movement_type: :reservation, quantity: 4, actor: @manager, order_item: garment)
    assert_equal 4.to_d, @item.reload.quantity_reserved
    assert_equal 16.to_d, @item.available_quantity
    assert_equal 4.to_d, @item.reserved_for(garment)

    @item.record_movement!(movement_type: :release, quantity: 1, actor: @manager, order_item: garment)
    @item.record_movement!(movement_type: :consumption, quantity: 3, actor: @manager, order_item: garment)

    assert_equal 17.to_d, @item.reload.quantity_on_hand
    assert_equal 0.to_d, @item.quantity_reserved
    assert_equal 0.to_d, @item.reserved_for(garment)
  end

  test "rejects unavailable stock and invalid order links" do
    draft = order_record

    assert_raises(InventoryItem::InvalidMovement) do
      @item.record_movement!(movement_type: :stock_out, quantity: 21, actor: @manager)
    end
    assert_raises(InventoryItem::InvalidMovement) do
      @item.record_movement!(movement_type: :reservation, quantity: 2, actor: @manager, order_item: draft.order_items.first)
    end
    assert_equal 20.to_d, @item.reload.quantity_on_hand
  end

  test "completing cutting consumes outstanding reservations" do
    order = confirmed_order
    garment = order.order_items.first
    task = garment.production_tasks.cutting.first
    cutter = users(:cutting)
    @item.record_movement!(movement_type: :reservation, quantity: 2.5, actor: @manager, order_item: garment)

    task.start!(cutter)
    task.complete!(cutter)

    assert_equal 17.5.to_d, @item.reload.quantity_on_hand
    assert_equal 0.to_d, @item.quantity_reserved
    assert garment.stock_movements.consumption.exists?
  end

  private

  def confirmed_order
    order_record.tap(&:confirm!)
  end

  def order_record
    Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Silk blouse", quantity: 1, unit_price: 1500 }
      }
    )
  end
end
