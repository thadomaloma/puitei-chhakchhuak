require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  test "manager expense is approved and receives a sequential voucher number" do
    first = create_expense(recorded_by: users(:manager))
    second = create_expense(recorded_by: users(:owner), description: "Machine oil")

    assert_equal "EXP-MAIN-#{Date.current.year}-00001", first.expense_number
    assert_equal "EXP-MAIN-#{Date.current.year}-00002", second.expense_number
    assert first.approval_approved?
    assert_equal users(:manager), first.approved_by
  end

  test "front desk expense remains pending until manager approval" do
    expense = create_expense(recorded_by: users(:receptionist))

    assert expense.approval_pending?
    assert_nil expense.approved_at

    expense.approve!(users(:manager))

    assert expense.reload.approval_approved?
    assert_equal users(:manager), expense.approved_by
  end

  test "approved totals exclude pending and void expenses" do
    approved = create_expense(recorded_by: users(:manager), amount: 700)
    create_expense(recorded_by: users(:cashier), description: "Pending parcel", amount: 300)
    voided = create_expense(recorded_by: users(:owner), description: "Duplicate parcel", amount: 200)
    voided.void!(users(:manager), reason: "Recorded twice")

    assert_equal approved.amount, Expense.active.sum(:amount)
    assert_equal 1, Expense.pending_review.count
  end

  test "void retains the record and financial details cannot change" do
    expense = create_expense(recorded_by: users(:manager))

    expense.void!(users(:owner), reason: "Incorrect invoice")

    assert expense.reload.voided?
    assert_equal "Incorrect invoice", expense.void_reason
    assert_not expense.update(amount: 999)
    assert expense.errors[:base].any? { |message| message.include?("cannot be changed") }
    assert_raises(Expense::InvalidVoid) { expense.void!(users(:manager), reason: "Again") }
  end

  test "cashier cannot approve or void expenses" do
    pending = create_expense(recorded_by: users(:receptionist))

    assert_raises(Expense::InvalidApproval) { pending.approve!(users(:cashier)) }
    assert_raises(Expense::InvalidVoid) { pending.void!(users(:cashier), reason: "Mistake") }
  end

  test "recurring entry creates a linked next occurrence without changing history" do
    original = create_expense(
      recorded_by: users(:manager), incurred_on: Date.current.prev_month(2),
      recurrence_interval: :monthly
    )

    generated = original.record_next!(users(:manager))

    assert_equal original.next_due_on, generated.incurred_on
    assert_equal original, generated.source_expense
    assert_equal generated.incurred_on.next_month, generated.next_due_on
    assert_equal original.amount, generated.amount
    assert_raises(Expense::InvalidRecurrence) { original.record_next!(users(:manager)) }
  end

  test "non-cash expense requires reference and future expense is rejected" do
    expense = Expense.new(
      branch: branches(:main), recorded_by: users(:manager), description: "Online tool",
      category: :equipment, amount: 500, incurred_on: Date.current + 1,
      payment_method: :card, recurrence_interval: :one_time
    )

    assert_not expense.valid?
    assert expense.errors[:reference_number].any?
    assert expense.errors[:incurred_on].any? { |message| message.include?("future") }
  end

  private

  def create_expense(attributes = {})
    Expense.create!({
      branch: branches(:main), recorded_by: users(:manager), description: "Workshop supplies",
      category: :other, amount: 450, currency: "INR", incurred_on: Date.current,
      payment_method: :cash, recurrence_interval: :one_time
    }.merge(attributes))
  end
end
