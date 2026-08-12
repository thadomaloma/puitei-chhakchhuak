require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 1, unit_price: 1500 }
      }
    )
    @order.confirm!
  end

  test "cashier records payment and can view and print its receipt" do
    sign_in users(:cashier)

    assert_difference("Payment.count") do
      post order_payments_path(@order), params: {
        payment: { amount: 500, payment_method: "cash", paid_on: Date.current, notes: "Advance" }
      }
    end

    payment = Payment.order(:id).last
    assert_redirected_to payment_path(payment)
    assert_equal users(:cashier), payment.received_by

    get payment_path(payment)
    assert_response :success
    assert_select "h1", payment.payment_number
    get receipt_payment_path(payment)
    assert_response :success
    assert_select "h1", I18n.t("payments.receipt")
  end

  test "manager voids a payment with a reason" do
    payment = @order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash)
    sign_in users(:manager)

    patch void_payment_path(payment), params: { payment: { void_reason: "Duplicate receipt" } }

    assert_redirected_to payment_path(payment)
    assert payment.reload.voided?
    assert_equal "Duplicate receipt", payment.void_reason
  end

  test "cashier cannot void a payment" do
    payment = @order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash)
    sign_in users(:cashier)

    patch void_payment_path(payment), params: { payment: { void_reason: "Mistake" } }

    assert_redirected_to root_path
    assert_not payment.reload.voided?
  end

  test "production users cannot access financial pages or see billing on an order" do
    sign_in users(:tailor)

    get payments_path
    assert_redirected_to root_path
    get order_path(@order)
    assert_response :success
    assert_select "h2", text: I18n.t("payments.billing"), count: 0
  end

  test "branch staff cannot access another branch payment" do
    payment = @order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash)
    sign_in users(:second_manager)

    get payment_path(payment)
    assert_response :not_found
  end

  test "payment dashboard includes active receipts" do
    payment = @order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash)
    sign_in users(:cashier)

    get payments_path

    assert_response :success
    assert_select "a[href='#{payment_path(payment)}']"
    assert_select "nav[aria-label='#{I18n.t('payments.status')}']"
    assert_select "details summary", text: /#{I18n.t('payments.date_range')}/
    assert_select "details summary", text: /#{I18n.t('payments.more_filters')}/
  end

  test "desktop filter chips preserve other payment filters when removed" do
    sign_in users(:cashier)

    get payments_path, params: { query: "Lal", status: "all", payment_method: "cash", from: Date.current, to: Date.current }

    assert_response :success
    assert_select ".filter-chip", minimum: 4
    assert_select "a[href='#{payments_path(query: "Lal", status: "all", from: Date.current, to: Date.current)}']", text: /Cash/
  end
end
