require "test_helper"

class InventoryItemPolicyTest < ActiveSupport::TestCase
  setup { @item = inventory_items(:silk) }

  test "all active roles can view branch inventory" do
    %i[owner manager receptionist cashier tailor cutting embroidery ironing].each do |role|
      assert InventoryItemPolicy.new(users(role), @item).show?, "expected #{role} to view inventory"
    end
  end

  test "only owners and managers manage catalogue records" do
    assert InventoryItemPolicy.new(users(:owner), @item).update?
    assert InventoryItemPolicy.new(users(:manager), @item).update?
    assert_not InventoryItemPolicy.new(users(:receptionist), @item).update?
    assert_not InventoryItemPolicy.new(users(:cutting), @item).update?
  end

  test "movement permissions follow operational roles" do
    stock_in = StockMovement.new(inventory_item: @item, movement_type: :stock_in)
    reservation = StockMovement.new(inventory_item: @item, movement_type: :reservation)
    consumption = StockMovement.new(inventory_item: @item, movement_type: :consumption)

    assert StockMovementPolicy.new(users(:manager), stock_in).create?
    assert StockMovementPolicy.new(users(:receptionist), reservation).create?
    assert_not StockMovementPolicy.new(users(:receptionist), stock_in).create?
    assert StockMovementPolicy.new(users(:cutting), consumption).create?
    assert_not StockMovementPolicy.new(users(:cashier), consumption).create?
  end

  test "other branch staff are denied" do
    assert_not InventoryItemPolicy.new(users(:second_manager), @item).show?
    movement = StockMovement.new(inventory_item: @item, movement_type: :stock_in)
    assert_not StockMovementPolicy.new(users(:second_manager), movement).create?
  end
end
