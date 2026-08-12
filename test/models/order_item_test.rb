require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Festival blouse", quantity: 1, unit_price: 1500 }
      }
    )
    @item = @order.order_items.first
  end

  test "captures a complete measurement snapshot" do
    snapshot = @item.measurement_snapshot

    assert_equal measurements(:alice_blouse_v1).id, snapshot.fetch("measurement_id")
    assert_equal 1, snapshot.fetch("version")
    assert_equal "inches", snapshot.fetch("unit")
    assert_equal "36.0", snapshot.dig("values", "bust")
    assert snapshot.fetch("fields").any? { |field| field["key"] == "bust" && field["label"] == "Bust" }
  end

  test "does not allow the snapshot or source measurement to change" do
    @item.measurement_snapshot["values"]["bust"] = "99"

    assert_not @item.save
    assert @item.errors[:measurement_snapshot].any?
    assert_not @item.update(measurement: measurements(:other_shirt_v1))
    assert @item.errors[:measurement].any?
  end

  test "rejects a measurement belonging to another customer" do
    item = @order.order_items.build(measurement: measurements(:other_shirt_v1), garment_name: "Shirt")

    assert_not item.valid?
    assert item.errors[:measurement].any? { |message| message.include?("order customer") }
  end

  test "attaching an approved design selection marks it used" do
    selection = design_selections(:alice_blouse)
    selection.update!(status: :approved)

    item = @order.order_items.create!(measurement: measurements(:alice_blouse_v1), design_selection: selection, garment_name: "Blouse")

    assert_equal selection, item.design_selection
    assert selection.reload.used?
  end

  test "attaching a non-approved design selection links it without forcing a status change" do
    selection = design_selections(:alice_blouse)
    assert selection.shortlisted?

    @order.order_items.create!(measurement: measurements(:alice_blouse_v1), design_selection: selection, garment_name: "Blouse")

    assert selection.reload.shortlisted?
  end

  test "rejects a design selection belonging to another customer" do
    other_selection = DesignSelection.create!(
      shop: shops(:primary), customer: customers(:carol), design: designs(:blouse_reference),
      selected_by: users(:manager), status: :shortlisted
    )
    item = @order.order_items.build(measurement: measurements(:alice_blouse_v1), design_selection: other_selection, garment_name: "Blouse")

    assert_not item.valid?
    assert item.errors[:design_selection].any? { |message| message.include?("order customer") }
  end

  test "does not allow the design selection to change after creation" do
    assert_not @item.update(design_selection: design_selections(:alice_blouse))
    assert @item.errors[:design_selection].any?
  end
end
