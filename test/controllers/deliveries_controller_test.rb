require "test_helper"

class DeliveriesControllerTest < ActionDispatch::IntegrationTest
  test "owner views the delivery desk across branches" do
    ready_order
    sign_in users(:owner)

    get deliveries_path

    assert_response :success
    assert_select "h1", I18n.t("deliveries.desk")
    assert_select "nav[aria-label='#{I18n.t('deliveries.view')}']"
    assert_select "details summary", text: /#{I18n.t('deliveries.date_range')}/
    assert_select "details summary", text: /#{I18n.t('deliveries.more_filters')}/
  end

  test "desktop filter chips preserve other delivery filters when removed" do
    sign_in users(:manager)

    get deliveries_path, params: { query: "Lal", view: "delivered", collection_method: "courier", from: Date.current, to: Date.current }

    assert_response :success
    assert_select ".filter-chip", minimum: 4
    assert_select "a[href='#{deliveries_path(query: "Lal", view: "delivered", from: Date.current, to: Date.current)}']", text: /Courier/
  end

  test "manager views the desk and completes a handover with receipt" do
    order = ready_order
    sign_in users(:manager)

    get deliveries_path
    assert_response :success
    assert_select "h1", I18n.t("deliveries.desk")
    assert_select "a[href='#{new_order_delivery_path(order)}']"
    assert_includes response.body, "INR 1,500.00"

    get new_order_delivery_path(order)
    assert_response :success
    assert_select "form[action='#{order_delivery_path(order)}']"

    assert_difference("Delivery.count") do
      post order_delivery_path(order), params: { delivery: delivery_params }
    end

    delivery = Delivery.order(:id).last
    assert_redirected_to delivery_path(delivery)
    assert order.reload.delivered?

    get delivery_path(delivery)
    assert_response :success
    assert_select "h1", delivery.delivery_number
    get receipt_delivery_path(delivery)
    assert_response :success
    assert_select "h1", I18n.t("deliveries.delivery_receipt")
  end

  test "receptionist needs manager authority for an outstanding handover" do
    order = ready_order
    sign_in users(:receptionist)

    get new_order_delivery_path(order)

    assert_redirected_to root_path
    assert_no_difference("Delivery.count") do
      post order_delivery_path(order), params: { delivery: delivery_params }
    end
    assert_redirected_to root_path
    assert order.reload.confirmed?
  end

  test "receptionist delivers a paid order" do
    order = ready_order
    order.record_payment(received_by: users(:cashier), amount: order.total_amount, payment_method: :cash)
    sign_in users(:receptionist)

    assert_difference("Delivery.count") do
      post order_delivery_path(order), params: { delivery: delivery_params }
    end

    assert order.reload.delivered?
  end

  test "cannot deliver an unfinished order" do
    order = base_order
    order.confirm!
    sign_in users(:manager)

    get new_order_delivery_path(order)

    assert_redirected_to root_path
    assert_no_difference("Delivery.count") do
      post order_delivery_path(order), params: { delivery: delivery_params }
    end
  end

  test "branch staff cannot see another branch handover" do
    order = ready_order
    delivery = order.deliver!(actor: users(:manager), attributes: delivery_attributes)
    sign_in users(:second_manager)

    get delivery_path(delivery)

    assert_response :not_found
  end

  private

  def ready_order
    base_order.tap do |order|
      order.confirm!
      order.order_items.each do |item|
        item.production_tasks.order(:position).each do |task|
          task.start!(users(:owner))
          task.complete!(users(:owner))
        end
      end
    end
  end

  def base_order
    Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Handover blouse", quantity: 1, unit_price: 1500 }
      }
    )
  end

  def delivery_params
    delivery_attributes.transform_values { |value| value == true ? "1" : value }
  end

  def delivery_attributes
    {
      recipient_name: "Lalhmingmawii", recipient_phone: "9862401001", collection_method: "customer_pickup",
      acknowledged_by: "Lalhmingmawii", recipient_acknowledged: true, quality_checked: true,
      garment_count_verified: true, payment_status_confirmed: true, packaging_complete: true,
      handed_over_at: Time.current.strftime("%Y-%m-%dT%H:%M")
    }
  end
end
