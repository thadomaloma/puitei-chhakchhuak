require "test_helper"

class PaymentPolicyTest < ActiveSupport::TestCase
  setup do
    order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 1, unit_price: 1500 }
      }
    )
    order.confirm!
    @payment = order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash)
  end

  test "cash desk roles can read and record payments" do
    %i[owner manager receptionist cashier].each do |role|
      policy = PaymentPolicy.new(users(role), @payment)
      assert policy.show?, "expected #{role} to view payments"
    end
  end

  test "only owners and managers can void payments" do
    assert PaymentPolicy.new(users(:owner), @payment).void?
    assert PaymentPolicy.new(users(:manager), @payment).void?
    assert_not PaymentPolicy.new(users(:receptionist), @payment).void?
    assert_not PaymentPolicy.new(users(:cashier), @payment).void?
  end

  test "production and other branch staff are denied" do
    assert_not PaymentPolicy.new(users(:tailor), @payment).show?
    assert_not PaymentPolicy.new(users(:second_manager), @payment).show?
  end
end
