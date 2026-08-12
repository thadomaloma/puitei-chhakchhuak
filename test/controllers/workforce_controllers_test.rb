require "test_helper"

class WorkforceControllersTest < ActionDispatch::IntegrationTest
  test "staff checks in and out once" do
    sign_in users(:tailor)
    get attendance_records_path
    assert_response :success

    assert_difference("AttendanceRecord.count") { post check_in_attendance_records_path }
    record = AttendanceRecord.last
    assert_redirected_to attendance_records_path
    assert_equal users(:tailor), record.user

    patch check_out_attendance_record_path(record)
    assert_redirected_to attendance_records_path
    assert record.reload.checked_out?
    assert_equal %w[checked_in checked_out], record.user.staff_events.order(:id).pluck(:event_type)
  end

  test "staff sees only own attendance" do
    other = AttendanceRecord.create!(
      branch: branches(:main), user: users(:cutting), work_date: Date.current,
      checked_in_at: 1.hour.ago
    )
    sign_in users(:tailor)

    get attendance_records_path
    assert_response :success
    assert_select "a[href='#{staff_path(other.user)}']", count: 0
  end

  test "staff submits and cancels leave" do
    sign_in users(:tailor)

    assert_difference("LeaveRequest.count") do
      post leave_requests_path, params: {
        leave_request: {
          leave_type: "personal", starts_on: Date.current + 2,
          ends_on: Date.current + 2, reason: "Appointment"
        }
      }
    end
    request = LeaveRequest.last
    assert_redirected_to leave_requests_path
    patch cancel_leave_request_path(request)
    assert request.reload.cancelled?
  end

  test "manager approves leave and staff cannot review" do
    request = LeaveRequest.create!(
      branch: branches(:main), user: users(:tailor), leave_type: :annual,
      starts_on: Date.current + 2, ends_on: Date.current + 4, reason: "Family event"
    )
    sign_in users(:manager)
    patch approve_leave_request_path(request), params: { leave_request: { review_notes: "Approved" } }
    assert request.reload.approved?

    second = LeaveRequest.create!(
      branch: branches(:main), user: users(:tailor), leave_type: :personal,
      starts_on: Date.current + 7, ends_on: Date.current + 7, reason: "Appointment"
    )
    sign_out users(:manager)
    sign_in users(:tailor)
    patch approve_leave_request_path(second)
    assert_redirected_to root_path
    assert second.reload.pending?
  end

  test "manager schedules and cancels a shift" do
    sign_in users(:manager)
    starts_at = 2.days.from_now.change(min: 0)

    assert_difference("WorkShift.count") do
      post work_shifts_path, params: {
        work_shift: {
          user_id: users(:tailor).id, starts_at: starts_at,
          ends_at: starts_at + 8.hours, location: "Main workshop"
        }
      }
    end
    shift = WorkShift.last
    assert_redirected_to work_shifts_path
    patch cancel_work_shift_path(shift), params: { work_shift: { cancel_reason: "Holiday" } }
    assert shift.reload.cancelled?
  end

  test "staff cannot schedule shifts" do
    sign_in users(:tailor)
    starts_at = 2.days.from_now.change(min: 0)

    assert_no_difference("WorkShift.count") do
      post work_shifts_path, params: {
        work_shift: { user_id: users(:tailor).id, starts_at: starts_at, ends_at: starts_at + 8.hours }
      }
    end
    assert_redirected_to root_path
  end
end
