require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  setup do
    @order = priced_order
    @order.confirm!
  end

  test "records partial payments with sequential receipt numbers" do
    first = @order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash, paid_on: Date.current)
    second = @order.record_payment(
      received_by: users(:cashier), amount: 1000, payment_method: :upi,
      reference_number: "UPI-123", paid_on: Date.current
    )

    assert_equal "RCT-MAIN-#{Date.current.year}-00001", first.payment_number
    assert_equal "RCT-MAIN-#{Date.current.year}-00002", second.payment_number
    assert_equal 1500.to_d, @order.paid_amount
    assert_equal 1500.to_d, @order.balance_due
    assert_equal "partial", @order.payment_status
  end

  test "rejects overpayment and non-cash payments without a reference" do
    overpayment = @order.payments.new(
      received_by: users(:cashier), amount: @order.total_amount + 1, payment_method: :cash, paid_on: Date.current
    )
    card = @order.payments.new(
      received_by: users(:cashier), amount: 100, payment_method: :card, paid_on: Date.current
    )

    assert_not overpayment.valid?
    assert overpayment.errors[:amount].any? { |message| message.include?("outstanding") }
    assert_not card.valid?
    assert card.errors[:reference_number].any?
  end

  test "cannot pay a draft order" do
    draft = priced_order
    payment = draft.payments.new(received_by: users(:cashier), amount: 100, payment_method: :cash)

    assert_not payment.valid?
    assert payment.errors[:order].any? { |message| message.include?("confirmed") }
  end

  test "payment date cannot be in the future" do
    payment = @order.payments.new(
      received_by: users(:cashier), amount: 100, payment_method: :cash, paid_on: Date.current + 1
    )

    assert_not payment.valid?
    assert payment.errors[:paid_on].any? { |message| message.include?("future") }
  end

  test "void keeps the receipt but restores the balance" do
    payment = @order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash)

    payment.void!(users(:manager), reason: "Entered twice")

    assert payment.reload.voided?
    assert_equal users(:manager), payment.voided_by
    assert_equal "Entered twice", payment.void_reason
    assert_equal 0.to_d, @order.reload.paid_amount
    assert_equal @order.total_amount, @order.balance_due
  end

  test "cashier cannot void and recorded financial details cannot change" do
    payment = @order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash)

    assert_raises(Payment::InvalidVoid) { payment.void!(users(:cashier), reason: "Mistake") }
    assert_not payment.update(amount: 600)
    assert payment.errors[:base].any? { |message| message.include?("cannot be changed") }
  end

  private

  def priced_order
    Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 2, unit_price: 1500 }
      }
    )
  end
end
