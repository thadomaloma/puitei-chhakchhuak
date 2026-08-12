require "test_helper"

class DashboardPolicyTest < ActiveSupport::TestCase
  test "active staff can view the dashboard" do
    assert DashboardPolicy.new(users(:tailor), :dashboard).show?
  end

  test "inactive staff cannot view the dashboard" do
    assert_not DashboardPolicy.new(users(:inactive), :dashboard).show?
  end
end
