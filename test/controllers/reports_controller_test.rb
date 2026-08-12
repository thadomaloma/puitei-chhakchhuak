require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "manager sees branch-scoped financial and operational results" do
    main_order = create_confirmed_order
    create_payment(main_order, amount: 400)
    create_expense(amount: 100)
    other_order = create_confirmed_order(
      branch: branches(:second), customer: customers(:other_branch),
      measurement: measurements(:other_shirt_v1), creator: users(:second_manager), price: 5000
    )
    create_payment(other_order, amount: 1000, receiver: users(:second_manager))
    sign_in users(:manager)

    get reports_path, params: { from: Date.current, to: Date.current }

    assert_response :success
    assert_select "h1", I18n.t("reports.title")
    assert_includes metric_text(I18n.t("reports.revenue")), "INR 400.00"
    assert_includes metric_text(I18n.t("reports.expenses")), "INR 100.00"
    assert_includes metric_text(I18n.t("reports.net_profit")), "INR 300.00"
    assert_includes metric_text(I18n.t("reports.order_value")), "INR 1,500.00"
    assert_select "a[href^='#{export_reports_path}']"
    assert_select "h2", I18n.t("reports.expense_breakdown")
  end

  test "owner report includes every branch in the current shop" do
    main_order = create_confirmed_order
    create_payment(main_order, amount: 400)
    other_order = create_confirmed_order(
      branch: branches(:second), customer: customers(:other_branch),
      measurement: measurements(:other_shirt_v1), creator: users(:second_manager), price: 5000
    )
    create_payment(other_order, amount: 1000, receiver: users(:second_manager))
    sign_in users(:owner)

    get reports_path, params: { from: Date.current, to: Date.current }

    assert_response :success
    assert_includes metric_text(I18n.t("reports.revenue")), "INR 1,400.00"
    assert_includes metric_text(I18n.t("reports.order_value")), "INR 6,750.00"
  end

  test "cash desk roles cannot access full business reports" do
    sign_in users(:cashier)

    get reports_path

    assert_redirected_to root_path
  end

  test "csv export includes advanced sections and neutralizes formulas" do
    formula_staff = User.create!(
      name: "=CMD", email: "formula-staff@example.test", password: "Password-123!",
      branch: branches(:main), role: :tailor, pay_basis: :monthly_salary, pay_rate: 0
    )
    Membership.create!(
      shop: shops(:primary), branch: branches(:main), user: formula_staff, role: :tailor,
      active: true, employee_code: formula_staff.employee_code, joined_on: formula_staff.joined_on,
      accepted_at: Time.current
    )
    AttendanceRecord.create!(
      branch: branches(:main), user: formula_staff, work_date: Date.current,
      checked_in_at: 2.hours.ago, checked_out_at: 1.hour.ago
    )
    sign_in users(:owner)

    get export_reports_path, params: { from: Date.current, to: Date.current }

    assert_response :success
    assert_includes response.media_type, "text/csv"
    assert_includes response.body, I18n.t("reports.expense_breakdown")
    assert_includes response.body, I18n.t("reports.staff_performance")
    assert_includes response.body, I18n.t("reports.staff_member")
    assert_includes response.body, "'=CMD"
  end

  private

  def create_confirmed_order(branch: branches(:main), customer: customers(:alice),
    measurement: measurements(:alice_blouse_v1), creator: users(:receptionist), price: 1500)
    order = Order.create!(
      branch: branch, customer: customer, created_by: creator,
      ordered_on: Date.current, delivery_date: Date.current + 7,
      order_items_attributes: {
        "0" => { measurement_id: measurement.id, garment_name: "Report garment", quantity: 1, unit_price: price }
      }
    )
    order.confirm!
    order
  end

  def create_payment(order, amount:, receiver: users(:manager))
    order.record_payment(
      amount: amount, payment_method: :cash, paid_on: Date.current, received_by: receiver
    )
  end

  def create_expense(amount:)
    Expense.create!(
      branch: branches(:main), recorded_by: users(:manager), description: "Report expense",
      category: :utilities, amount: amount, currency: "INR", incurred_on: Date.current,
      payment_method: :cash, recurrence_interval: :one_time
    )
  end

  def metric_text(label)
    card = response.parsed_body.css("article.metric-card").find { |node| node.text.include?(label) }
    card&.text.to_s.squish
  end
end
