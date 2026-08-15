require "test_helper"

class SchedulePolicyTest < ActiveSupport::TestCase
  test "active staff of any role can view the schedule" do
    assert SchedulePolicy.new(users(:owner), :schedule).show?
    assert SchedulePolicy.new(users(:receptionist), :schedule).show?
    assert SchedulePolicy.new(users(:cashier), :schedule).show?
    assert SchedulePolicy.new(users(:tailor), :schedule).show?
  end

  test "inactive staff cannot view the schedule" do
    assert_not SchedulePolicy.new(users(:inactive), :schedule).show?
  end

  test "only owner and manager can filter the schedule by staff" do
    assert SchedulePolicy.new(users(:owner), :schedule).filter_staff?
    assert SchedulePolicy.new(users(:manager), :schedule).filter_staff?
    assert_not SchedulePolicy.new(users(:receptionist), :schedule).filter_staff?
    assert_not SchedulePolicy.new(users(:cashier), :schedule).filter_staff?
    assert_not SchedulePolicy.new(users(:tailor), :schedule).filter_staff?
  end
end
