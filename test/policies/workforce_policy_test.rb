require "test_helper"

class WorkforcePolicyTest < ActiveSupport::TestCase
  test "owner manages all staff and manager cannot manage owners" do
    assert UserPolicy.new(users(:owner), users(:second_manager)).show?
    assert UserPolicy.new(users(:owner), users(:tailor)).compensation?
    assert UserPolicy.new(users(:manager), users(:tailor)).update?
    assert_not UserPolicy.new(users(:manager), users(:owner)).update?
    assert_not UserPolicy.new(users(:manager), users(:manager)).archive?
  end

  test "staff sees only own attendance leave and shifts" do
    attendance = AttendanceRecord.new(branch: branches(:main), user: users(:tailor))
    other_attendance = AttendanceRecord.new(branch: branches(:main), user: users(:cutting))
    leave = LeaveRequest.new(branch: branches(:main), user: users(:tailor))
    shift = WorkShift.new(branch: branches(:main), user: users(:tailor))

    assert AttendanceRecordPolicy.new(users(:tailor), attendance).create?
    assert_not AttendanceRecordPolicy.new(users(:tailor), other_attendance).show?
    assert LeaveRequestPolicy.new(users(:tailor), leave).create?
    assert WorkShiftPolicy.new(users(:tailor), shift).show?
    assert_not WorkShiftPolicy.new(users(:tailor), shift).create?
  end

  test "manager workforce scopes remain branch limited" do
    assert_equal users(:manager).branch.users.count, UserPolicy::Scope.new(users(:manager), User).resolve.count
    assert_not UserPolicy.new(users(:manager), users(:second_manager)).show?
  end
end
