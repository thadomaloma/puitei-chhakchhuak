require "test_helper"

class ExpensePolicyTest < ActiveSupport::TestCase
  setup do
    @pending = Expense.create!(
      branch: branches(:main), recorded_by: users(:receptionist), description: "Courier charge",
      category: :transport, amount: 300, currency: "INR", incurred_on: Date.current,
      payment_method: :cash, recurrence_interval: :one_time
    )
  end

  test "cash desk roles can read and record branch expenses" do
    %i[owner manager receptionist cashier].each do |role|
      policy = ExpensePolicy.new(users(role), @pending)
      assert policy.show?, "expected #{role} to view expenses"
      assert policy.create?, "expected #{role} to record expenses"
    end
  end

  test "only owners and managers can approve and void" do
    assert ExpensePolicy.new(users(:owner), @pending).approve?
    assert ExpensePolicy.new(users(:manager), @pending).approve?
    assert_not ExpensePolicy.new(users(:receptionist), @pending).approve?
    assert_not ExpensePolicy.new(users(:cashier), @pending).void?
  end

  test "production and other branch staff are denied" do
    assert_not ExpensePolicy.new(users(:tailor), @pending).show?
    assert_not ExpensePolicy.new(users(:second_manager), @pending).show?
  end
end
