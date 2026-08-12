class WorkShiftsController < ApplicationController
  before_action :set_work_shift, only: :cancel

  def index
    authorize WorkShift
    shifts = policy_scope(WorkShift).includes(:user, :created_by).where(ends_at: 7.days.ago..).chronological
    shifts = shifts.where(user_id: params[:user_id]) if params[:user_id].present?
    @pagy, @work_shifts = pagy(:offset, shifts, limit: 30)
    @staff_options = active_staff_scope.order(:name) if current_user.owner? || current_user.manager?
  end

  def new
    @work_shift = current_branch.work_shifts.new(starts_at: Time.current.change(min: 0) + 1.day, ends_at: Time.current.change(min: 0) + 1.day + 8.hours)
    authorize @work_shift
    @staff_options = active_staff_scope.order(:name)
  end

  def create
    staff_member = active_staff_scope.find(work_shift_params[:user_id])
    membership = staff_member.membership_for(current_shop)
    @work_shift = staff_member.work_shifts.new(
      work_shift_params.except(:user_id).merge(branch: membership.branch, created_by: current_user)
    )
    authorize @work_shift
    if @work_shift.save
      StaffEvent.record!(
        staff_member: staff_member, actor: current_user, event_type: "shift_scheduled",
        details: { work_shift_id: @work_shift.id, starts_at: @work_shift.starts_at, ends_at: @work_shift.ends_at }
      )
      redirect_to work_shifts_path, notice: t("work_shifts.created")
    else
      @staff_options = active_staff_scope.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def cancel
    authorize @work_shift, :cancel?
    @work_shift.cancel!(current_user, reason: params.require(:work_shift).fetch(:cancel_reason))
    redirect_to work_shifts_path, notice: t("work_shifts.cancelled")
  rescue WorkShift::InvalidCancellation, ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
    redirect_to work_shifts_path, alert: error.message
  end

  private

  def set_work_shift
    @work_shift = policy_scope(WorkShift).find(params[:id])
  end

  def work_shift_params
    params.require(:work_shift).permit(:user_id, :starts_at, :ends_at, :location, :notes)
  end

  def active_staff_scope
    policy_scope(User).active.where(memberships: { active: true })
  end
end
