require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  test "owner scope includes staff from every branch" do
    scope = UserPolicy::Scope.new(users(:owner), User).resolve

    assert_includes scope, users(:second_manager)
  end

  test "manager scope is limited to their branch" do
    scope = UserPolicy::Scope.new(users(:manager), User).resolve

    assert_includes scope, users(:tailor)
    assert_not_includes scope, users(:second_manager)
  end

  test "production staff cannot list users" do
    assert_not UserPolicy.new(users(:tailor), User).index?
  end
end
