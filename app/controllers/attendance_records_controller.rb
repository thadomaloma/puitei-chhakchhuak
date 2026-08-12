class AttendanceRecordsController < ApplicationController
  before_action :set_attendance_record, only: :check_out

  def index
    authorize AttendanceRecord
    records = policy_scope(AttendanceRecord).includes(:user, :branch).recent_first
    records = records.where(user_id: params[:user_id]) if params[:user_id].present?
    records = records.where(work_date: params[:date]) if params[:date].present?
    @pagy, @attendance_records = pagy(:offset, records, limit: 30)
    @today_record = current_user.attendance_for
    @staff_options = active_staff_scope.order(:name) if current_user.owner? || current_user.manager?
  end

  def check_in
    record = current_user.attendance_records.new(
      branch: current_branch, work_date: Date.current, checked_in_at: Time.current,
      notes: params.dig(:attendance_record, :notes)
    )
    authorize record, :create?
    record.save!
    StaffEvent.record!(staff_member: current_user, actor: current_user, event_type: "checked_in", details: { attendance_id: record.id })
    redirect_to attendance_records_path, notice: t("attendance.checked_in")
  rescue ActiveRecord::RecordInvalid => error
    redirect_to attendance_records_path, alert: error.record.errors.full_messages.to_sentence
  end

  def check_out
    authorize @attendance_record, :check_out?
    @attendance_record.check_out!(current_user, notes: params.dig(:attendance_record, :notes))
    redirect_to attendance_records_path, notice: t("attendance.checked_out")
  rescue AttendanceRecord::InvalidCheckout, ActiveRecord::RecordInvalid => error
    redirect_to attendance_records_path, alert: error.message
  end

  private

  def set_attendance_record
    @attendance_record = policy_scope(AttendanceRecord).find(params[:id])
  end

  def active_staff_scope
    policy_scope(User).active.where(memberships: { active: true })
  end
end
