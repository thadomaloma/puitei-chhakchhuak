require "test_helper"

class ReportPolicyTest < ActiveSupport::TestCase
  test "owners and managers can access and export business reports" do
    %i[owner manager].each do |role|
      policy = ReportPolicy.new(users(role), :report)
      assert policy.index?, "expected #{role} to access reports"
      assert policy.export?, "expected #{role} to export reports"
    end
  end

  test "cash desk and production roles cannot access business reports" do
    %i[receptionist cashier tailor].each do |role|
      assert_not ReportPolicy.new(users(role), :report).index?, "expected #{role} to be denied"
    end
  end
end
