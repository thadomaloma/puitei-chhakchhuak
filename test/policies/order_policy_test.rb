require "test_helper"

class OrderPolicyTest < ActiveSupport::TestCase
  setup do
    @order = Order.new(branch: branches(:main), customer: customers(:alice), status: :draft)
  end

  test "front desk roles can create and confirm" do
    %i[owner manager receptionist].each do |role|
      policy = OrderPolicy.new(users(role), @order)
      assert policy.create?, "expected #{role} to create orders"
      assert policy.confirm?, "expected #{role} to confirm orders"
    end
  end

  test "cashiers and production staff have read only access" do
    %i[cashier tailor].each do |role|
      policy = OrderPolicy.new(users(role), @order)
      assert policy.show?, "expected #{role} to view orders"
      assert_not policy.create?, "expected #{role} not to create orders"
      assert_not policy.confirm?, "expected #{role} not to confirm orders"
    end
  end

  test "non owners are branch scoped" do
    @order.branch = branches(:second)

    assert_not OrderPolicy.new(users(:manager), @order).show?
    assert OrderPolicy.new(users(:owner), @order).show?
  end
end
