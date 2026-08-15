require "application_system_test_case"

class ScheduleTest < ApplicationSystemTestCase
  test "receptionist reviews today's schedule on mobile and opens an order" do
    order = create_order(trial_date: Date.current, delivery_date: 10.days.from_now.to_date)
    page.current_window.resize_to(390, 844)
    sign_in_as users(:receptionist)

    visit schedule_path

    assert_responsive_document
    assert_selector "h1", text: I18n.t("schedule.title")
    assert_text order.customer.full_name
    click_link I18n.t("schedule.view_order"), match: :first
    assert_current_path order_path(order)
  end

  test "owner filters the schedule by staff on desktop" do
    order = create_order(delivery_date: Date.current)
    order.order_items.first.production_tasks.find_by!(stage: :cutting).update!(assigned_to: users(:cutting))
    page.current_window.resize_to(1440, 1000)
    sign_in_as users(:owner)

    visit schedule_path

    assert_responsive_document
    select users(:cutting).name, from: "staff_id"
    click_button I18n.t("forms.search")

    assert_text order.customer.full_name
  end

  private

  def create_order(delivery_date:, trial_date: nil, customer: customers(:alice), branch: branches(:main))
    order = Order.create!(
      branch: branch, customer: customer, created_by: users(:receptionist),
      ordered_on: 30.days.ago.to_date, delivery_date: delivery_date, trial_date: trial_date,
      order_items_attributes: {
        "0" => { measurement_id: measurements(:alice_blouse_v1).id, garment_name: "Studio garment", quantity: 1, unit_price: 1500 }
      }
    )
    order.confirm!
    order
  end
end
