require "test_helper"

class OrderReminderJobTest < ActiveJob::TestCase
  setup do
    @due_today_order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current - 3, delivery_date: Date.current,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 1, unit_price: 1500 }
      }
    )
    @due_today_order.confirm!

    @overdue_order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current - 10, delivery_date: Date.current - 2,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Kurti", quantity: 1, unit_price: 1200 }
      }
    )
    @overdue_order.confirm!
  end

  test "notifies owners and managers of the branch for due-today and overdue orders" do
    OrderReminderJob.perform_now

    due_today_notifications = Notification.where(notifiable: @due_today_order, notification_type: :due_today)
    overdue_notifications = Notification.where(notifiable: @overdue_order, notification_type: :overdue)

    assert_equal [ users(:owner), users(:manager) ].to_set, due_today_notifications.map(&:recipient).to_set
    assert_equal [ users(:owner), users(:manager) ].to_set, overdue_notifications.map(&:recipient).to_set
  end

  test "does not notify staff outside owner/manager roles or managers of other branches" do
    OrderReminderJob.perform_now

    recipients = Notification.where(notifiable: @due_today_order).pluck(:recipient_id)
    assert_not_includes recipients, users(:tailor).id
    assert_not_includes recipients, users(:second_manager).id
  end

  test "is idempotent when run more than once" do
    OrderReminderJob.perform_now

    assert_no_difference("Notification.count") { OrderReminderJob.perform_now }
  end

  test "does not notify for orders that are neither due today nor overdue" do
    future_order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 14,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Gown", quantity: 1, unit_price: 3000 }
      }
    )
    future_order.confirm!

    OrderReminderJob.perform_now

    assert_not Notification.exists?(notifiable: future_order)
  end
end
