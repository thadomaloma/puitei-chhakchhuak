class LeaveRequestsController < ApplicationController
  before_action :set_leave_request, only: %i[approve reject cancel]

  def index
    authorize LeaveRequest
    requests = policy_scope(LeaveRequest).includes(:user, :reviewed_by).recent_first
    requests = requests.where(status: params[:status]) if LeaveRequest.statuses.key?(params[:status])
    @pagy, @leave_requests = pagy(:offset, requests, limit: 25)
    @pending_count = policy_scope(LeaveRequest).pending.count
    @approved_upcoming_count = policy_scope(LeaveRequest).approved.where(ends_on: Date.current..).count
  end

  def new
    @leave_request = current_user.leave_requests.new(branch: current_branch, starts_on: Date.current, ends_on: Date.current)
    authorize @leave_request
  end

  def create
    @leave_request = current_user.leave_requests.new(leave_request_params.merge(branch: current_branch))
    authorize @leave_request
    if @leave_request.save
      StaffEvent.record!(
        staff_member: current_user, actor: current_user, event_type: "leave_requested",
        details: { leave_request_id: @leave_request.id, starts_on: @leave_request.starts_on, ends_on: @leave_request.ends_on }
      )
      redirect_to leave_requests_path, notice: t("leave_requests.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def approve
    review(:approved)
  end

  def reject
    review(:rejected)
  end

  def cancel
    authorize @leave_request, :cancel?
    @leave_request.cancel!(current_user)
    redirect_to leave_requests_path, notice: t("leave_requests.cancelled")
  rescue LeaveRequest::InvalidReview, ActiveRecord::RecordInvalid => error
    redirect_to leave_requests_path, alert: error.message
  end

  private

  def set_leave_request
    @leave_request = policy_scope(LeaveRequest).find(params[:id])
  end

  def review(decision)
    authorize @leave_request, :review?
    @leave_request.review!(current_user, decision: decision, notes: params.dig(:leave_request, :review_notes))
    redirect_to leave_requests_path, notice: t("leave_requests.#{decision}")
  rescue LeaveRequest::InvalidReview, ActiveRecord::RecordInvalid => error
    redirect_to leave_requests_path, alert: error.message
  end

  def leave_request_params
    params.require(:leave_request).permit(:leave_type, :starts_on, :ends_on, :reason)
  end
end
