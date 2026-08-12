class StaffController < ApplicationController
  before_action :set_staff, only: %i[show edit update archive]
  before_action :set_staff_membership, only: %i[show edit update archive]
  helper_method :staff_membership

  def index
    authorize User
    staff = policy_scope(User).search(params[:query]).order(:name)
    staff = staff.where(memberships: { role: Membership.roles[params[:role]] }) if Membership.roles.key?(params[:role])
    staff = staff.where(memberships: { active: true }) unless params[:archived] == "1"
    @pagy, @staff_members = pagy(:offset, staff, limit: 24)
    @staff_memberships = current_shop.memberships.includes(:branch).where(user_id: @staff_members).index_by(&:user_id)

    scoped = policy_scope(User)
    @active_count = scoped.where(memberships: { active: true }).count
    @checked_in_count = policy_scope(AttendanceRecord).where(work_date: Date.current, checked_out_at: nil).count
    @pending_leave_count = policy_scope(LeaveRequest).pending.count
    @active_task_count = policy_scope(ProductionTask).where.not(status: %i[completed skipped]).count
  end

  def show
    authorize @staff
    @attendance_records = policy_scope(AttendanceRecord).where(user: @staff).recent_first.limit(10)
    @leave_requests = policy_scope(LeaveRequest).where(user: @staff).recent_first.limit(8)
    @upcoming_shifts = policy_scope(WorkShift).where(user: @staff).active.where(starts_at: Time.current..).chronological.limit(8)
    @staff_events = policy_scope(StaffEvent).where(staff_member: @staff).recent_first.limit(12)
    tasks = policy_scope(ProductionTask)
    @active_tasks = tasks.where(assigned_to: @staff).where.not(status: %i[completed skipped]).count
    @completed_this_month = tasks.completed.where(completed_by: @staff, completed_at: Time.current.all_month).count
    duration = Arel.sql("EXTRACT(EPOCH FROM (COALESCE(checked_out_at, CURRENT_TIMESTAMP) - checked_in_at)) / 3600.0")
    @attendance_hours = policy_scope(AttendanceRecord).where(user: @staff, work_date: Date.current.all_month).sum(duration)
  end

  def new
    @staff = current_branch.users.new(joined_on: Date.current, pay_basis: :monthly_salary)
    authorize @staff
  end

  def create
    @staff = current_branch.users.new(staff_params)
    authorize @staff

    ApplicationRecord.transaction do
      @staff.save!
      membership = current_shop.memberships.create!(membership_attributes(@staff))
      StaffEvent.record!(staff_member: @staff, actor: current_user, event_type: "staff_created", details: { role: @staff.role })
      BusinessAuditEvent.record!(action: "membership.created", shop: current_shop, actor: current_user, auditable: membership)
    end
    redirect_to staff_path(@staff), notice: t("staff.created")
  rescue ActiveRecord::RecordInvalid => error
    @staff ||= current_branch.users.new(staff_params)
    message = error.record.errors.full_messages.to_sentence
    @staff.errors.add(:base, message) unless @staff.errors.full_messages.include?(message)
    render :new, status: :unprocessable_entity
  end

  def edit
    authorize @staff
    @staff.assign_attributes(
      role: @staff_membership.role, active: @staff_membership.active,
      joined_on: @staff_membership.joined_on, pay_basis: @staff_membership.pay_basis,
      pay_rate: @staff_membership.pay_rate
    )
  end

  def update
    @staff.assign_attributes(staff_params)
    authorize @staff
    changes = @staff.changes.transform_values { |values| values.map(&:to_s) }.except("encrypted_password", "password")

    ApplicationRecord.transaction do
      @staff.save!
      membership = @staff.memberships.find_by!(shop: current_shop)
      was_active = membership.active?
      membership.update!(membership_attributes(@staff).except(:user, :accepted_at))
      @staff.update!(active: @staff.memberships.active.exists?)
      event_type = !was_active && membership.active? ? "staff_reactivated" : "profile_updated"
      StaffEvent.record!(staff_member: @staff, actor: current_user, event_type: event_type, details: changes)
      BusinessAuditEvent.record!(action: "membership.role_changed", shop: current_shop, actor: current_user, auditable: membership, metadata: changes.slice("role")) if changes.key?("role")
    end
    redirect_to staff_path(@staff), notice: t("staff.updated")
  rescue ActiveRecord::RecordInvalid => error
    @staff.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == @staff
    render :edit, status: :unprocessable_entity
  end

  def archive
    authorize @staff, :archive?
    ApplicationRecord.transaction do
      StaffEvent.record!(staff_member: @staff, actor: current_user, event_type: "staff_archived")
      membership = @staff.memberships.find_by!(shop: current_shop)
      BusinessAuditEvent.record!(action: "membership.archived", shop: current_shop, actor: current_user, auditable: membership)
      membership.update!(active: false)
      @staff.update!(active: false) unless @staff.memberships.active.exists?
    end
    redirect_to staff_index_path, notice: t("staff.archived")
  end

  private

  def set_staff
    @staff = policy_scope(User).find(params[:id])
  end

  def set_staff_membership
    @staff_membership = current_shop.memberships.find_by!(user: @staff)
  end

  def staff_membership(staff_member)
    return @staff_membership if @staff_membership&.user_id == staff_member.id

    @staff_memberships.fetch(staff_member.id)
  end

  def staff_params
    permitted = %i[name email phone_number job_title joined_on role emergency_contact active password password_confirmation]
    permitted += %i[pay_basis pay_rate] if current_user.owner?
    attributes = params.require(:user).permit(permitted)
    if action_name == "update" && attributes[:password].blank?
      attributes.delete(:password)
      attributes.delete(:password_confirmation)
    end
    attributes
  end

  def membership_attributes(staff_member)
    branch = staff_member.memberships.find_by(shop: current_shop)&.branch || current_branch
    {
      user: staff_member, branch: branch, role: staff_member.role, active: staff_member.active,
      employee_code: staff_member.employee_code, joined_on: staff_member.joined_on,
      pay_basis: staff_member.pay_basis, pay_rate: staff_member.pay_rate, accepted_at: Time.current
    }
  end
end
