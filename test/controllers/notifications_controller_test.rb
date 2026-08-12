require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @order = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Blouse", quantity: 1, unit_price: 1500 }
      }
    )
    @order.confirm!
    @manager_notification = Notification.notify_once!(
      recipient: users(:manager), notification_type: :due_today, notifiable: @order,
      title: "Order due today", message: "Test message"
    )
    @owner_notification = Notification.notify_once!(
      recipient: users(:owner), notification_type: :due_today, notifiable: @order,
      title: "Order due today", message: "Test message"
    )
  end

  test "index only shows the current user's own notifications" do
    sign_in users(:manager)

    get notifications_path

    assert_response :success
    assert_select "body", text: /Test message/
  end

  test "read marks the notification read and redirects to the order" do
    sign_in users(:manager)

    patch read_notification_path(@manager_notification)

    assert_redirected_to @order
    assert @manager_notification.reload.read?
  end

  test "a user cannot mark another user's notification as read" do
    sign_in users(:manager)

    patch read_notification_path(@owner_notification)

    assert_response :not_found
    assert_not @owner_notification.reload.read?
  end

  test "read_all marks only the current user's unread notifications" do
    sign_in users(:manager)

    patch read_all_notifications_path

    assert_redirected_to notifications_path
    assert @manager_notification.reload.read?
    assert_not @owner_notification.reload.read?
  end
end
