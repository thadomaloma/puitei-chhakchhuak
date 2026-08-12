require "test_helper"

class DeliveryTest < ActiveSupport::TestCase
  test "records an immutable handover snapshot and delivers the order" do
    first_order = ready_order
    second_order = ready_order

    first = first_order.deliver!(actor: users(:manager), attributes: delivery_attributes)
    second = second_order.deliver!(actor: users(:manager), attributes: delivery_attributes(recipient_name: "Authorized collector"))

    assert_equal "DLV-MAIN-#{Date.current.year}-00001", first.delivery_number
    assert_equal "DLV-MAIN-#{Date.current.year}-00002", second.delivery_number
    assert first_order.reload.delivered?
    assert_equal first_order.total_amount, first.total_amount_snapshot
    assert_equal first_order.balance_due, first.balance_due_snapshot
    assert_not first.update(recipient_name: "Changed")
    assert_not first.destroy
    assert Delivery.exists?(first.id)
  end

  test "requires complete production and every release check" do
    order = base_order
    order.confirm!

    assert_raises(ActiveRecord::RecordInvalid) do
      order.deliver!(actor: users(:manager), attributes: delivery_attributes)
    end

    complete_production(order)
    attributes = delivery_attributes(quality_checked: false)
    assert_raises(ActiveRecord::RecordInvalid) do
      order.deliver!(actor: users(:manager), attributes: attributes)
    end
    assert order.reload.confirmed?
  end

  test "outstanding delivery requires an owner or manager" do
    order = ready_order

    error = assert_raises(ActiveRecord::RecordInvalid) do
      order.deliver!(actor: users(:receptionist), attributes: delivery_attributes)
    end

    assert_includes error.record.errors.full_messages.to_sentence, "owner or manager"
    delivery = order.deliver!(actor: users(:manager), attributes: delivery_attributes)
    assert delivery.balance_due_snapshot.positive?
  end

  test "receptionist can hand over a fully paid order" do
    order = ready_order
    order.record_payment(received_by: users(:cashier), amount: order.total_amount, payment_method: :cash)

    delivery = order.deliver!(actor: users(:receptionist), attributes: delivery_attributes)

    assert delivery.persisted?
    assert_equal 0.to_d, delivery.balance_due_snapshot
  end

  test "delivered orders continue accepting later balance payments" do
    order = ready_order
    order.deliver!(actor: users(:manager), attributes: delivery_attributes)

    payment = order.record_payment(received_by: users(:cashier), amount: 500, payment_method: :cash)

    assert payment.persisted?
    assert order.reload.delivered?
  end

  private

  def ready_order
    base_order.tap do |order|
      order.confirm!
      complete_production(order)
    end
  end

  def base_order
    Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Delivery blouse", quantity: 1, unit_price: 1500 }
      }
    )
  end

  def complete_production(order)
    order.order_items.each do |item|
      item.production_tasks.order(:position).each do |task|
        task.start!(users(:owner)) if task.pending?
        task.complete!(users(:owner)) if task.in_progress?
      end
    end
  end

  def delivery_attributes(overrides = {})
    {
      recipient_name: "Lalhmingmawii", recipient_phone: "9862401001",
      collection_method: :customer_pickup, acknowledged_by: "Lalhmingmawii",
      recipient_acknowledged: true, quality_checked: true, garment_count_verified: true,
      payment_status_confirmed: true, packaging_complete: true, handed_over_at: Time.current
    }.merge(overrides)
  end
end
