require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "assigns sequential branch and year order numbers" do
    first = build_order
    second = build_order

    assert first.save!
    assert second.save!
    assert_equal "TLR-MAIN-#{Date.current.year}-00001", first.order_number
    assert_equal "TLR-MAIN-#{Date.current.year}-00002", second.order_number
    assert_equal 2, second.sequence_number
  end

  test "requires trial and delivery dates to follow the order date" do
    order = build_order(trial_date: Date.current - 1, delivery_date: Date.current + 2)

    assert_not order.valid?
    assert order.errors[:trial_date].any?
  end

  test "confirmation requires a garment" do
    order = Order.new(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7, status: :confirmed
    )

    assert_not order.valid?
    assert order.errors[:order_items].any?
  end

  test "confirmation freezes discount tax currency and total" do
    branches(:main).shop_setting.update!(tax_rate: 10)
    order = build_order(discount_amount: 100)

    order.confirm!

    assert_equal 1500.to_d, order.subtotal_amount
    assert_equal 100.to_d, order.discount_amount
    assert_equal 10.to_d, order.tax_rate_snapshot
    assert_equal 140.to_d, order.tax_amount
    assert_equal 1540.to_d, order.total_amount
    assert_equal "INR", order.currency
    assert_not_nil order.pricing_finalized_at

    branches(:main).shop_setting.update!(tax_rate: 5)
    assert_equal 10.to_d, order.reload.tax_rate_snapshot
    assert_not order.update(total_amount: 1)
    assert order.errors[:base].any? { |message| message.include?("pricing") }
  end

  test "draft can persist a discount before its totals are finalized" do
    order = build_order(discount_amount: 100)

    assert order.save!
    assert order.draft?
    assert_nil order.pricing_finalized_at
  end

  test "cannot confirm an unpriced garment" do
    order = build_order
    order.save!
    order.order_items.first.update!(unit_price: 0)

    assert_raises(ActiveRecord::RecordInvalid) { order.confirm! }
    assert order.reload.draft?
  end

  private

  def build_order(attributes = {})
    order = Order.new({
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7
    }.merge(attributes))
    order.order_items.build(measurement: measurements(:alice_blouse_v1), garment_name: "Blouse", quantity: 1, unit_price: 1500)
    order
  end
end
