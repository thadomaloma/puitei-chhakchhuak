require "test_helper"

class WorkforceTest < ActiveSupport::TestCase
  test "attendance and shifts are isolated per shop for multi-shop staff" do
    foreign_branch = Branch.create!(
      shop: shops(:foreign), name: "Foreign Studio", code: "FOREIGN-WF", locale: "en", time_zone: "Asia/Kolkata"
    )
    Membership.create!(
      shop: shops(:foreign), branch: foreign_branch, user: users(:tailor), role: :tailor,
      employee_code: "STF-FOREIGN-WF-0001", joined_on: Date.current, accepted_at: Time.current
    )
    Membership.create!(
      shop: shops(:foreign), branch: foreign_branch, user: users(:manager), role: :manager,
      employee_code: "STF-FOREIGN-WF-0002", joined_on: Date.current, accepted_at: Time.current
    )

    primary_attendance = AttendanceRecord.create!(
      branch: branches(:main), user: users(:tailor), work_date: Date.current, checked_in_at: 2.hours.ago
    )
    foreign_attendance = AttendanceRecord.create!(
      branch: foreign_branch, user: users(:tailor), work_date: Date.current, checked_in_at: 1.hour.ago
    )
    starts_at = 2.days.from_now.change(min: 0)
    WorkShift.create!(
      branch: branches(:main), user: users(:tailor), created_by: users(:manager),
      starts_at: starts_at, ends_at: starts_at + 8.hours
    )
    foreign_shift = WorkShift.new(
      branch: foreign_branch, user: users(:tailor), created_by: users(:manager),
      starts_at: starts_at, ends_at: starts_at + 8.hours
    )

    assert foreign_shift.valid?
    assert_equal primary_attendance, users(:tailor).attendance_for(Date.current, shops(:primary))
    assert_equal foreign_attendance, users(:tailor).attendance_for(Date.current, shops(:foreign))
  end

  test "new staff receives a branch-scoped employee code and workforce defaults" do
    staff = User.create!(
      branch: branches(:main), name: "New Tailor", email: "new-tailor@example.test",
      password: "Password-123!", role: :tailor
    )

    assert_match(/\ASTF-MAIN-\d{4,}\z/, staff.employee_code)
    assert_equal Date.current, staff.joined_on
    assert staff.pay_monthly_salary?
  end

  test "attendance checks out once and records immutable audit events" do
    record = AttendanceRecord.create!(
      branch: branches(:main), user: users(:tailor), work_date: Date.current,
      checked_in_at: 2.hours.ago
    )
    StaffEvent.record!(staff_member: users(:tailor), actor: users(:tailor), event_type: "checked_in")

    record.check_out!(users(:tailor), notes: "Completed shift")

    assert record.reload.checked_out?
    assert_in_delta 2, record.duration_hours, 0.1
    assert_equal %w[checked_out checked_in], users(:tailor).staff_events.recent_first.pluck(:event_type)
    assert_raises(AttendanceRecord::InvalidCheckout) { record.check_out!(users(:tailor)) }
    assert_not record.update(checked_in_at: 3.hours.ago)
  end

  test "staff cannot check out another staff member" do
    record = AttendanceRecord.create!(
      branch: branches(:main), user: users(:tailor), work_date: Date.current,
      checked_in_at: 1.hour.ago
    )

    assert_raises(AttendanceRecord::InvalidCheckout) { record.check_out!(users(:cutting)) }
  end

  test "manager approves leave and request details remain immutable" do
    request = LeaveRequest.create!(
      branch: branches(:main), user: users(:tailor), leave_type: :annual,
      starts_on: Date.current + 3, ends_on: Date.current + 5, reason: "Family event"
    )

    request.review!(users(:manager), decision: :approved, notes: "Coverage arranged")

    assert request.reload.approved?
    assert_equal users(:manager), request.reviewed_by
    assert_equal "Coverage arranged", request.review_notes
    assert_not request.update(reason: "Changed")
    assert_equal "leave_approved", users(:tailor).staff_events.last.event_type
  end

  test "approved leave cannot overlap another request" do
    LeaveRequest.create!(
      branch: branches(:main), user: users(:tailor), leave_type: :annual,
      starts_on: Date.current + 3, ends_on: Date.current + 5, reason: "First"
    ).review!(users(:manager), decision: :approved)
    overlap = LeaveRequest.new(
      branch: branches(:main), user: users(:tailor), leave_type: :personal,
      starts_on: Date.current + 5, ends_on: Date.current + 6, reason: "Overlap"
    )

    assert_not overlap.valid?
    assert overlap.errors[:base].any? { |message| message.include?("overlaps") }
  end

  test "staff cancels pending leave but cannot review it" do
    request = LeaveRequest.create!(
      branch: branches(:main), user: users(:tailor), leave_type: :personal,
      starts_on: Date.current + 1, ends_on: Date.current + 1, reason: "Appointment"
    )

    assert_raises(LeaveRequest::InvalidReview) { request.review!(users(:tailor), decision: :approved) }
    request.cancel!(users(:tailor))
    assert request.reload.cancelled?
  end

  test "manager schedules and cancels non-overlapping shifts" do
    shift = WorkShift.create!(
      branch: branches(:main), user: users(:tailor), created_by: users(:manager),
      starts_at: 1.day.from_now, ends_at: 1.day.from_now + 8.hours, location: "Main workshop"
    )
    overlap = WorkShift.new(
      branch: branches(:main), user: users(:tailor), created_by: users(:manager),
      starts_at: shift.starts_at + 1.hour, ends_at: shift.ends_at + 1.hour
    )

    assert_not overlap.valid?
    shift.cancel!(users(:manager), reason: "Workshop closed")
    assert shift.reload.cancelled?
    assert_equal "Workshop closed", shift.cancel_reason
    assert_equal "shift_cancelled", users(:tailor).staff_events.last.event_type
  end

  test "staff event is immutable" do
    event = StaffEvent.record!(staff_member: users(:cashier), actor: users(:manager), event_type: "profile_updated")

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(event_type: "staff_archived") }
  end
end
