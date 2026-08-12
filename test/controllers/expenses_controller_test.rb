require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  test "cashier records pending expense and can view and print it" do
    sign_in users(:cashier)

    assert_difference("Expense.count") do
      post expenses_path, params: {
        expense: {
          description: "Courier charge", category: "transport", amount: 350,
          incurred_on: Date.current, vendor: "Fast Courier", payment_method: "cash",
          recurrence_interval: "one_time", notes: "Customer garment delivery"
        }
      }
    end

    expense = Expense.order(:id).last
    assert_redirected_to expense_path(expense)
    assert expense.approval_pending?
    assert_equal users(:cashier), expense.recorded_by

    get expense_path(expense)
    assert_response :success
    assert_select "h1", expense.expense_number
    get voucher_expense_path(expense)
    assert_response :success
    assert_select "h1", I18n.t("expenses.expense_voucher")
  end

  test "manager records an approved expense" do
    sign_in users(:manager)

    post expenses_path, params: {
      expense: {
        description: "Electricity bill", category: "utilities", amount: 2500,
        incurred_on: Date.current, vendor: "Power department", payment_method: "upi",
        reference_number: "POWER-123", recurrence_interval: "monthly"
      }
    }

    expense = Expense.order(:id).last
    assert_redirected_to expense_path(expense)
    assert expense.approval_approved?
    assert_equal Date.current.next_month, expense.next_due_on
  end

  test "manager approves and voids with an audit reason" do
    expense = create_expense(recorded_by: users(:receptionist))
    sign_in users(:manager)

    patch approve_expense_path(expense)
    assert_redirected_to expense_path(expense)
    assert expense.reload.approval_approved?

    patch void_expense_path(expense), params: { expense: { void_reason: "Invoice cancelled" } }
    assert_redirected_to expense_path(expense)
    assert expense.reload.voided?
    assert_equal "Invoice cancelled", expense.void_reason
  end

  test "cashier cannot approve or void" do
    expense = create_expense(recorded_by: users(:receptionist))
    sign_in users(:cashier)

    patch approve_expense_path(expense)
    assert_redirected_to root_path
    patch void_expense_path(expense), params: { expense: { void_reason: "No" } }
    assert_redirected_to root_path
    assert expense.reload.approval_pending?
    assert_not expense.voided?
  end

  test "branch staff cannot access another branch expense" do
    expense = create_expense(recorded_by: users(:manager))
    sign_in users(:second_manager)

    get expense_path(expense)

    assert_response :not_found
  end

  test "production users cannot access expenses" do
    sign_in users(:tailor)

    get expenses_path

    assert_redirected_to root_path
  end

  test "expense dashboard filters and exports safe csv" do
    expense = create_expense(recorded_by: users(:manager), description: "=FORMULA", category: :rent)
    create_expense(recorded_by: users(:manager), description: "Transport", category: :transport)
    sign_in users(:manager)

    get expenses_path, params: { category: "rent", status: "approved" }
    assert_response :success
    assert_select "a[href='#{expense_path(expense)}']"
    assert_select "a", text: "EXP-MAIN-#{Date.current.year}-00002", count: 0

    get export_expenses_path(format: :csv), params: { category: "rent" }
    assert_response :success
    assert_includes response.media_type, "text/csv"
    assert_includes response.body, "'=FORMULA"
  end

  test "records a due recurring occurrence once" do
    expense = create_expense(
      recorded_by: users(:manager), incurred_on: Date.current.prev_month(2),
      recurrence_interval: :monthly
    )
    sign_in users(:manager)

    assert_difference("Expense.count") { post record_next_expense_path(expense) }
    generated = Expense.order(:id).last
    assert_redirected_to expense_path(generated)
    assert_equal expense, generated.source_expense

    assert_no_difference("Expense.count") { post record_next_expense_path(expense) }
  end

  private

  def create_expense(attributes = {})
    Expense.create!({
      branch: branches(:main), recorded_by: users(:manager), description: "Workshop expense",
      category: :other, amount: 450, currency: "INR", incurred_on: Date.current,
      payment_method: :cash, recurrence_interval: :one_time
    }.merge(attributes))
  end
end
