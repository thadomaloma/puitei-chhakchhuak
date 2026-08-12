require "test_helper"

class NotificationTest < ActiveSupport::TestCase
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

  test "notify_once! creates a notification and derives the shop from the notifiable" do
    notification = Notification.notify_once!(
      recipient: users(:manager), notification_type: :due_today, notifiable: @order,
      title: "Order due today", message: "Test message"
    )

    assert notification.persisted?
    assert_equal shops(:primary), notification.shop
    assert_not notification.read?
  end

  test "notify_once! is idempotent for the same recipient, type, and notifiable" do
    2.times do
      Notification.notify_once!(
        recipient: users(:manager), notification_type: :due_today, notifiable: @order,
        title: "Order due today", message: "Test message"
      )
    end

    assert_equal 1, Notification.where(recipient: users(:manager), notification_type: :due_today, notifiable: @order).count
  end

  test "mark_read! sets read_at once and is idempotent" do
    notification = Notification.notify_once!(
      recipient: users(:manager), notification_type: :due_today, notifiable: @order,
      title: "Order due today", message: "Test message"
    )

    notification.mark_read!
    read_at = notification.reload.read_at
    assert_not_nil read_at
    notification.mark_read!
    assert_equal read_at, notification.reload.read_at
  end

  test "unread and recent_first scopes" do
    older = Notification.notify_once!(
      recipient: users(:manager), notification_type: :due_today, notifiable: @order,
      title: "Older", message: "Older message"
    )
    older.update!(created_at: 1.day.ago)
    newer = Notification.notify_once!(
      recipient: users(:manager), notification_type: :overdue, notifiable: @order,
      title: "Newer", message: "Newer message"
    )
    newer.mark_read!

    assert_equal [ older ], Notification.unread.to_a
    assert_equal [ newer, older ], Notification.recent_first.to_a
  end
end
