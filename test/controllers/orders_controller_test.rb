require "test_helper"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:receptionist) }

  test "renders the premium order directory with operational filters and metrics" do
    order = create_order

    get orders_path

    assert_response :success
    assert_select "h1", I18n.t("orders.title")
    assert_select "select#order_status_desktop"
    assert_select "select#order_schedule_desktop"
    assert_select "a[href='#{order_path(order)}']", text: order.order_number
    assert_select "a[href='#{new_order_path}']", text: /#{I18n.t('orders.new')}/
    assert_includes response.body, I18n.t("orders.metrics.outstanding")
  end

  test "searches orders by customer WhatsApp number" do
    customers(:alice).update!(whatsapp_number: "9862000099")
    order = create_order

    get orders_path, params: { query: "9862000099" }

    assert_response :success
    assert_includes response.body, order.order_number
  end

  test "filters confirmed orders by overdue delivery" do
    order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: 10.days.ago.to_date, delivery_date: 2.days.ago.to_date,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Overdue blouse", quantity: 1, unit_price: 1500 }
      }
    )
    order.confirm!
    create_order

    get orders_path, params: { schedule: "overdue" }

    assert_response :success
    assert_includes response.body, order.order_number
    assert_includes response.body, I18n.t("orders.delivery_states.overdue", count: 2)
  end

  test "renders a dynamic order workflow with live pricing and snapshot guidance" do
    get new_order_path(customer_id: customers(:alice).id)

    assert_response :success
    assert_select "form[data-controller='order-form']"
    assert_select "template[data-order-form-target='template']"
    assert_select "[data-action='order-form#addItem']", minimum: 1
    assert_select "[data-order-form-target='subtotal']"
    assert_select "select[data-order-form-target='measurement']", minimum: 1
    assert_includes response.body, I18n.t("orders.snapshot_protection")
  end

  test "creates an order draft with an immutable measurement snapshot" do
    assert_difference([ "Order.count", "OrderItem.count" ]) do
      post orders_path, params: {
        order: {
          customer_id: customers(:alice).id,
          ordered_on: Date.current,
          trial_date: Date.current + 3,
          delivery_date: Date.current + 7,
          notes: "Wedding order",
          order_items_attributes: {
            "0" => {
              measurement_id: measurements(:alice_blouse_v1).id,
              garment_name: "Wedding blouse", quantity: 2, unit_price: 1500,
              special_instructions: "Silk lining"
            }
          }
        }
      }
    end

    order = Order.order(:id).last
    assert_redirected_to order_path(order)
    assert order.draft?
    assert_equal "36.0", order.order_items.first.measurement_snapshot.dig("values", "bust")
  end

  test "creates multiple garment records with separate measurement snapshots" do
    assert_difference("Order.count", 1) do
      assert_difference("OrderItem.count", 2) do
        post orders_path, params: {
          order: {
            customer_id: customers(:alice).id,
            ordered_on: Date.current,
            delivery_date: Date.current + 7,
            order_items_attributes: {
              "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Ceremony blouse", quantity: 1, unit_price: 1500 },
              "171" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Reception blouse", quantity: 1, unit_price: 1800 }
            }
          }
        }
      end
    end

    order = Order.order(:id).last
    assert_redirected_to order_path(order)
    assert_equal [ "Ceremony blouse", "Reception blouse" ], order.order_items.order(:id).pluck(:garment_name)
    assert order.order_items.all? { |item| item.measurement_snapshot.fetch("version") == 1 }
  end

  test "confirms a valid draft and renders its job card and QR code" do
    order = create_order

    patch confirm_order_path(order)
    assert_redirected_to order_path(order)
    assert order.reload.confirmed?
    assert_not_nil order.confirmed_at

    get order_path(order)
    assert_response :success
    assert_select "#production-task-#{order.order_items.first.production_tasks.first.id}"

    get job_card_order_path(order)
    assert_response :success
    assert_select "h1", I18n.t("orders.job_card")

    get qr_code_order_path(order, format: :svg)
    assert_response :success
    assert_equal "image/svg+xml", response.media_type
    assert_includes response.body, "<svg"
  end

  test "cannot create an order with another customer's measurement" do
    assert_no_difference("Order.count") do
      post orders_path, params: {
        order: {
          customer_id: customers(:alice).id, ordered_on: Date.current, delivery_date: Date.current + 7,
          order_items_attributes: {
            "0" => { measurement_id: measurements(:other_shirt_v1).id, garment_name: "Wrong shirt", quantity: 1, unit_price: 1200 }
          }
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "cashier can read orders but cannot create or confirm" do
    order = create_order
    sign_out users(:receptionist)
    sign_in users(:cashier)

    get order_path(order)
    assert_response :success
    get new_order_path
    assert_redirected_to root_path
    patch confirm_order_path(order)
    assert_redirected_to root_path
    assert order.reload.draft?
  end

  test "branch staff cannot view another branch order" do
    order = Order.create!(
      branch: branches(:second), customer: customers(:other_branch), created_by: users(:second_manager),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:other_shirt_v1).id, garment_name: "Office shirt", quantity: 1, unit_price: 1200 }
      }
    )

    get order_path(order)
    assert_response :not_found
  end

  test "attaching an approved design selection marks it used and links it to the garment" do
    selection = design_selections(:alice_blouse)
    selection.update!(status: :approved)

    assert_difference("Order.count") do
      post orders_path, params: {
        order: {
          customer_id: customers(:alice).id,
          ordered_on: Date.current, delivery_date: Date.current + 7,
          order_items_attributes: {
            "0" => {
              measurement_id: measurements(:alice_blouse_v1).id, design_selection_id: selection.id,
              garment_name: "Blouse", quantity: 1, unit_price: 1500
            }
          }
        }
      }
    end

    order = Order.order(:id).last
    assert_equal selection, order.order_items.first.design_selection
    assert selection.reload.used?
  end

  test "new order form lists the customer's active design selections" do
    get new_order_path(customer_id: customers(:alice).id)

    assert_response :success
    assert_select "select[data-order-form-target='designSelection'] option", text: /#{Regexp.escape(designs(:blouse_reference).title)}/
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
