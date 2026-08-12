require "test_helper"

class CustomerPolicyTest < ActiveSupport::TestCase
  test "receptionist can manage customers in their branch" do
    policy = CustomerPolicy.new(users(:receptionist), customers(:alice))

    assert policy.show?
    assert policy.create?
    assert policy.update?
  end

  test "cashier can view but not edit customers" do
    policy = CustomerPolicy.new(users(:cashier), customers(:alice))

    assert policy.show?
    assert_not policy.update?
  end

  test "production staff cannot access the customer directory" do
    assert_not CustomerPolicy.new(users(:tailor), Customer).index?
  end

  test "manager scope excludes another branch" do
    scope = CustomerPolicy::Scope.new(users(:manager), Customer).resolve

    assert_includes scope, customers(:alice)
    assert_not_includes scope, customers(:other_branch)
  end

  test "owner scope includes every branch" do
    scope = CustomerPolicy::Scope.new(users(:owner), Customer).resolve

    assert_includes scope, customers(:other_branch)
  end
end
