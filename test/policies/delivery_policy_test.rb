require "test_helper"

class DeliveryPolicyTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Policy blouse", quantity: 1, unit_price: 1500 }
      }
    )
    @order.confirm!
    @order.order_items.first.production_tasks.order(:position).each do |task|
      task.start!(users(:owner))
      task.complete!(users(:owner))
    end
  end

  test "cash desk roles can access the delivery desk" do
    %i[owner manager receptionist cashier].each do |role|
      assert DeliveryPolicy.new(users(role), Delivery).index?, "expected #{role} to access deliveries"
    end
    assert_not DeliveryPolicy.new(users(:tailor), Delivery).index?
  end

  test "outstanding handover is restricted to managers" do
    manager_record = Delivery.new(order: @order, branch: @order.branch, delivered_by: users(:manager))
    receptionist_record = Delivery.new(order: @order, branch: @order.branch, delivered_by: users(:receptionist))

    assert DeliveryPolicy.new(users(:manager), manager_record).create?
    assert_not DeliveryPolicy.new(users(:receptionist), receptionist_record).create?
    assert_not DeliveryPolicy.new(users(:cashier), receptionist_record).create?
  end

  test "paid handover is available to receptionist and cashier" do
    @order.record_payment(received_by: users(:cashier), amount: @order.total_amount, payment_method: :cash)

    %i[receptionist cashier].each do |role|
      record = Delivery.new(order: @order, branch: @order.branch, delivered_by: users(role))
      assert DeliveryPolicy.new(users(role), record).create?
    end
  end

  test "production and other branch staff are denied" do
    record = Delivery.new(order: @order, branch: @order.branch, delivered_by: users(:manager))

    assert_not DeliveryPolicy.new(users(:tailor), record).create?
    assert_not DeliveryPolicy.new(users(:second_manager), record).create?
  end
end
