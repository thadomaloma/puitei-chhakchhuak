require "test_helper"

class ProductionTaskPolicyTest < ActiveSupport::TestCase
  setup do
    order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 1, unit_price: 1500 }
      }
    )
    order.confirm!
    @task = order.order_items.first.production_tasks.find_by!(stage: :cutting)
  end

  test "matching production role can claim but unrelated role cannot" do
    assert ProductionTaskPolicy.new(users(:cutting), @task).claim?
    assert_not ProductionTaskPolicy.new(users(:tailor), @task).claim?
  end

  test "manager can assign and skip but receptionist cannot" do
    manager = ProductionTaskPolicy.new(users(:manager), @task)
    receptionist = ProductionTaskPolicy.new(users(:receptionist), @task)

    assert manager.assign?
    assert manager.skip?
    assert_not receptionist.assign?
    assert_not receptionist.skip?
  end

  test "all active staff can view branch work while another branch is denied" do
    assert ProductionTaskPolicy.new(users(:cashier), @task).show?
    assert_not ProductionTaskPolicy.new(users(:second_manager), @task).show?
    assert ProductionTaskPolicy.new(users(:owner), @task).show?
  end
end
