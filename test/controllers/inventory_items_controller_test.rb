require "test_helper"

class InventoryItemsControllerTest < ActionDispatch::IntegrationTest
  test "directory renders stock health and filters by supplier and low stock" do
    sign_in users(:manager)

    get inventory_items_path

    assert_response :success
    assert_select "h1", I18n.t("inventory.title")
    assert_select "#inventory-filter-panel"
    assert_includes response.body, I18n.t("inventory.stock_value")

    get inventory_items_path, params: { query: "Main Textile Supplier" }
    assert_response :success
    assert_select "a[href='#{inventory_item_path(inventory_items(:silk))}']", minimum: 1

    get inventory_items_path, params: { stock: "low" }
    assert_response :success
    assert_select "a[href='#{inventory_item_path(inventory_items(:low_thread))}']", minimum: 1
    assert_select "a[href='#{inventory_item_path(inventory_items(:silk))}']", count: 0
  end

  test "item workspace renders projected movement balances and active order allocations" do
    order = create_order
    order.confirm!
    item = inventory_items(:silk)
    item.record_movement!(movement_type: :reservation, quantity: 2.5, actor: users(:manager), order_item: order.order_items.first)
    sign_in users(:manager)

    get inventory_item_path(item)

    assert_response :success
    assert_select "[data-controller='inventory-movement']"
    assert_select "[data-inventory-movement-target='projectedOnHand']"
    assert_select "a[href='#{order_path(order)}']", text: /#{order.order_number}/
    assert_includes response.body, I18n.t("inventory.active_reservations")
  end

  test "filters immutable movement history by movement type" do
    item = inventory_items(:silk)
    item.record_movement!(movement_type: :stock_in, quantity: 2, actor: users(:manager), reference: "FILTER-IN")
    item.record_movement!(movement_type: :stock_out, quantity: 1, actor: users(:manager), reference: "FILTER-OUT")
    sign_in users(:manager)

    get inventory_item_path(item), params: { movement_type: "stock_in" }

    assert_response :success
    assert_select "[data-movement-type='stock_in']", minimum: 1
    assert_select "[data-movement-type='stock_out']", count: 0
    assert_includes response.body, "FILTER-IN"
    assert_not_includes response.body, "FILTER-OUT"
  end

  test "rejects unknown movement types without changing the ledger" do
    sign_in users(:manager)
    item = inventory_items(:silk)

    assert_no_difference("StockMovement.count") do
      post stock_movements_path, params: {
        stock_movement: {
          inventory_item_id: item.id, movement_type: "mystery", quantity: 1, happened_on: Date.current
        }
      }
    end

    assert_redirected_to inventory_item_path(item)
    assert_equal "Unknown stock movement", flash[:alert]
  end

  test "manager manages the catalogue and records stock" do
    sign_in users(:manager)

    get inventory_items_path
    assert_response :success
    assert_select "h1", I18n.t("inventory.title")
    assert_select "a[href='#{inventory_item_path(inventory_items(:silk))}']"

    assert_difference("InventoryItem.count") do
      post inventory_items_path, params: {
        inventory_item: {
          name: "Cotton canvas", sku: "FAB-CAN-002", category: "fabric", unit: "metre",
          color: "Natural", cost_price: 250, selling_price: 340, reorder_level: 8
        }
      }
    end
    item = InventoryItem.order(:id).last
    assert_redirected_to inventory_item_path(item)

    assert_difference("StockMovement.count") do
      post stock_movements_path, params: {
        stock_movement: {
          inventory_item_id: item.id, movement_type: "stock_in", quantity: 15,
          happened_on: Date.current, reference: "INV-2026-1"
        }
      }
    end
    assert_redirected_to inventory_item_path(item)
    assert_equal 15.to_d, item.reload.quantity_on_hand
  end

  test "receptionist reserves and releases material from a confirmed order" do
    order = create_order
    order.confirm!
    garment = order.order_items.first
    sign_in users(:receptionist)

    post stock_movements_path, params: {
      stock_movement: {
        inventory_item_id: inventory_items(:silk).id, order_item_id: garment.id,
        movement_type: "reservation", quantity: 3, happened_on: Date.current, return_to: "order"
      }
    }

    assert_redirected_to order_path(order)
    assert_equal 3.to_d, inventory_items(:silk).reload.quantity_reserved

    post stock_movements_path, params: {
      stock_movement: {
        inventory_item_id: inventory_items(:silk).id, order_item_id: garment.id,
        movement_type: "release", quantity: 3, happened_on: Date.current, return_to: "order"
      }
    }
    assert_equal 0.to_d, inventory_items(:silk).reload.quantity_reserved
  end

  test "cashier has read-only inventory access" do
    sign_in users(:cashier)

    get inventory_item_path(inventory_items(:silk))
    assert_response :success
    assert_select "form[action='#{stock_movements_path}']", count: 0

    assert_no_difference("StockMovement.count") do
      post stock_movements_path, params: {
        stock_movement: {
          inventory_item_id: inventory_items(:silk).id, movement_type: "stock_in",
          quantity: 5, happened_on: Date.current
        }
      }
    end
    assert_redirected_to root_path
  end

  test "branch staff cannot access another branch inventory" do
    sign_in users(:manager)

    get inventory_item_path(inventory_items(:other_silk))
    assert_response :not_found
  end

  test "reserved items cannot be archived" do
    order = create_order
    order.confirm!
    item = inventory_items(:silk)
    item.record_movement!(movement_type: :reservation, quantity: 1, actor: users(:manager), order_item: order.order_items.first)
    sign_in users(:manager)

    patch archive_inventory_item_path(item)

    assert_redirected_to root_path
    assert item.reload.active?
  end

  private

  def create_order
    Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 1, unit_price: 1500 }
      }
    )
  end
end
