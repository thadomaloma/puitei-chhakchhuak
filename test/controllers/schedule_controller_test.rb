require "test_helper"

class ScheduleControllerTest < ActionDispatch::IntegrationTest
  test "redirects guests to sign in" do
    get schedule_path

    assert_redirected_to new_user_session_path
  end

  test "shows today's fittings and deliveries for the receptionist" do
    fitting_order = create_order(trial_date: Date.current, delivery_date: 10.days.from_now.to_date)
    delivery_order = create_order(delivery_date: Date.current)
    sign_in users(:receptionist)

    get schedule_path

    assert_response :success
    assert_select "h1", I18n.t("schedule.title")
    assert_select "a[href='#{order_path(fitting_order)}']"
    assert_select "a[href='#{order_path(delivery_order)}']"
  end

  test "renders the empty state when nothing is scheduled today" do
    sign_in users(:receptionist)

    get schedule_path

    assert_response :success
    assert_includes response.body, I18n.t("schedule.empty_today")
  end

  test "week view groups entries by date" do
    order = create_order(delivery_date: Date.current.end_of_week)
    sign_in users(:receptionist)

    get schedule_path(view: "week")

    assert_response :success
    assert_select "a[href='#{order_path(order)}']"
  end

  test "cancelled orders are not shown even when their dates fall in range" do
    order = create_order(delivery_date: Date.current)
    order.update_column(:status, Order.statuses[:cancelled])
    sign_in users(:receptionist)

    get schedule_path

    assert_response :success
    assert_select "a[href='#{order_path(order)}']", count: 0
  end

  test "staff filter is only available to owner and manager" do
    sign_in users(:owner)

    get schedule_path

    assert_response :success
    assert_select "select#staff_id"
  end

  test "receptionist cannot filter by staff" do
    sign_in users(:receptionist)

    get schedule_path

    assert_response :success
    assert_select "select#staff_id", count: 0
  end

  test "tailor sees only their own assigned work by default" do
    mine = create_order(delivery_date: Date.current)
    mine.order_items.first.production_tasks.find_by!(stage: :cutting).update_columns(assigned_to_id: users(:tailor).id)
    other = create_order(delivery_date: Date.current, customer: customers(:carol), measurement: measurements(:carol_dress_v1))
    sign_in users(:tailor)

    get schedule_path

    assert_response :success
    assert_select "a[href='#{order_path(mine)}']"
    assert_select "a[href='#{order_path(other)}']", count: 0
  end

  test "search narrows results by customer name" do
    matching = create_order(delivery_date: Date.current, customer: customers(:alice))
    other = create_order(delivery_date: Date.current, customer: customers(:carol), measurement: measurements(:carol_dress_v1))
    sign_in users(:receptionist)

    get schedule_path(query: "Alice")

    assert_response :success
    assert_select "a[href='#{order_path(matching)}']"
    assert_select "a[href='#{order_path(other)}']", count: 0
  end

  private

  def create_order(delivery_date:, trial_date: nil, customer: customers(:alice), branch: branches(:main),
    measurement: measurements(:alice_blouse_v1), ordered_on: 30.days.ago.to_date)
    order = Order.create!(
      branch: branch, customer: customer, created_by: users(:receptionist),
      ordered_on: ordered_on, delivery_date: delivery_date, trial_date: trial_date,
      order_items_attributes: {
        "0" => { measurement_id: measurement.id, garment_name: "Studio garment", quantity: 1, unit_price: 1500 }
      }
    )
    order.confirm!
    order
  end
end
