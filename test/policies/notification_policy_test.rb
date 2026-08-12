require "test_helper"

class NotificationPolicyTest < ActiveSupport::TestCase
  setup do
    @order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 1, unit_price: 1500 }
      }
    )
    @order.confirm!
    @notification = Notification.notify_once!(
      recipient: users(:manager), notification_type: :due_today, notifiable: @order,
      title: "Order due today", message: "Test message"
    )
  end

  test "any active user can view their notifications index" do
    assert NotificationPolicy.new(users(:manager), Notification).index?
    assert_not NotificationPolicy.new(users(:inactive), Notification).index?
  end

  test "only the recipient can mark their notification as read" do
    assert NotificationPolicy.new(users(:manager), @notification).update?
    assert_not NotificationPolicy.new(users(:owner), @notification).update?
  end

  test "scope resolves only to the current user's notifications" do
    other_notification = Notification.notify_once!(
      recipient: users(:owner), notification_type: :due_today, notifiable: @order,
      title: "Order due today", message: "Test message"
    )

    resolved = NotificationPolicy::Scope.new(users(:manager), Notification.all).resolve
    assert_includes resolved, @notification
    assert_not_includes resolved, other_notification
  end
end
