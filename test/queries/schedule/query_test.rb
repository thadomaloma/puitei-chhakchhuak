require "test_helper"

class Schedule::QueryTest < ActiveSupport::TestCase
  test "fitting entries include orders with a trial date in range" do
    order = create_order(trial_date: Date.current, delivery_date: 10.days.from_now.to_date)

    query = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current)

    assert_includes query.fitting_entries.map(&:order), order
    assert_empty query.delivery_entries
  end

  test "delivery entries include orders with a delivery date in range" do
    order = create_order(delivery_date: Date.current)

    query = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current)

    assert_includes query.delivery_entries.map(&:order), order
  end

  test "orders without a trial date do not produce a fitting entry" do
    create_order(delivery_date: Date.current)

    query = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current)

    assert_empty query.fitting_entries
  end

  test "draft and cancelled orders are excluded from the schedule" do
    draft = Order.create!(
      branch: branches(:main), customer: customers(:alice), created_by: users(:receptionist),
      ordered_on: Date.current, delivery_date: Date.current, trial_date: Date.current,
      order_items_attributes: { "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Draft blouse", quantity: 1, unit_price: 1000 } }
    )
    cancelled = create_order(delivery_date: Date.current, trial_date: Date.current)
    cancelled.update_column(:status, Order.statuses[:cancelled])

    query = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current)

    refute_includes query.fitting_entries.map(&:order), draft
    refute_includes query.delivery_entries.map(&:order), cancelled
  end

  test "overdue fitting entries are trial dates before today on active orders" do
    order = create_order(trial_date: 2.days.ago.to_date, delivery_date: 5.days.from_now.to_date)

    query = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current)

    entry = query.overdue_entries.find { |candidate| candidate.order == order && candidate.fitting? }
    assert entry
    assert_equal 2, entry.days_overdue
  end

  test "overdue delivery entries reuse the authoritative Order.overdue scope" do
    order = create_order(delivery_date: 3.days.ago.to_date)

    query = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current)

    entry = query.overdue_entries.find { |candidate| candidate.order == order && candidate.delivery? }
    assert entry
    assert Order.overdue.exists?(order.id)
  end

  test "a date changed on the order is reflected immediately with no persisted schedule record" do
    order = create_order(delivery_date: 10.days.from_now.to_date)
    before = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current)
    assert_empty before.delivery_entries

    order.update_column(:delivery_date, Date.current)
    after = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current)

    assert_includes after.delivery_entries.map(&:order), order
  end

  test "search filters entries by customer name" do
    matching = create_order(delivery_date: Date.current, customer: customers(:alice))
    other = create_order(
      delivery_date: Date.current, customer: customers(:other_branch), branch: branches(:second),
      measurement: measurements(:other_shirt_v1), creator: users(:second_manager)
    )

    query = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current, search: "Alice")

    order_ids = query.delivery_entries.map(&:order).map(&:id)
    assert_includes order_ids, matching.id
    refute_includes order_ids, other.id
  end

  test "type filter narrows results to a single entry type" do
    create_order(trial_date: Date.current, delivery_date: Date.current)

    fittings_only = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current, type: "fitting")

    assert_equal 1, fittings_only.fitting_entries.size
    assert_empty fittings_only.delivery_entries
  end

  test "staff filter scopes to orders with a production task assigned to that staff" do
    order = create_order(delivery_date: Date.current)
    order.order_items.first.production_tasks.find_by!(stage: :cutting).update!(assigned_to: users(:cutting))

    scoped = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current, staff_id: users(:cutting).id)
    other_staff = Schedule::Query.new(orders: Order.all, from: Date.current, to: Date.current, staff_id: users(:embroidery).id)

    assert_includes scoped.delivery_entries.map(&:order), order
    refute_includes other_staff.delivery_entries.map(&:order), order
  end

  test "grouped_by_date groups entries by their date" do
    today_order = create_order(delivery_date: Date.current)
    tomorrow_order = create_order(delivery_date: 1.day.from_now.to_date)

    query = Schedule::Query.new(orders: Order.all, from: Date.current, to: 1.day.from_now.to_date)
    grouped = query.grouped_by_date

    assert_includes grouped[Date.current].map(&:order), today_order
    assert_includes grouped[1.day.from_now.to_date].map(&:order), tomorrow_order
  end

  private

  def create_order(delivery_date:, trial_date: nil, customer: customers(:alice), branch: branches(:main),
    measurement: measurements(:alice_blouse_v1), creator: users(:receptionist), ordered_on: 30.days.ago.to_date)
    order = Order.create!(
      branch: branch, customer: customer, created_by: creator,
      ordered_on: ordered_on, delivery_date: delivery_date, trial_date: trial_date,
      order_items_attributes: {
        "0" => { measurement_id: measurement.id, garment_name: "Studio garment", quantity: 1, unit_price: 1500 }
      }
    )
    order.confirm!
    order
  end
end
