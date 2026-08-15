class ScheduleController < ApplicationController
  VIEWS = %w[today week].freeze
  PRODUCTION_ROLES = %w[tailor cutting_staff embroidery_staff ironing_staff].freeze

  def show
    authorize :schedule, :show?

    @view = VIEWS.include?(params[:view]) ? params[:view] : "today"
    @anchor = parse_date(params[:date]) || Date.current
    @from, @to = date_range(@view, @anchor)
    @type = Schedule::Query::TYPES.include?(params[:type]) ? params[:type] : nil
    @can_filter_staff = policy(:schedule).filter_staff?
    @staff_options = @can_filter_staff ? staff_options : []
    @staff_id = resolve_staff_id
    @my_schedule = !@can_filter_staff && current_user.role_for.in?(PRODUCTION_ROLES)

    @query = Schedule::Query.new(
      orders: policy_scope(Order), from: @from, to: @to, type: @type, staff_id: @staff_id, search: params[:query]
    )
  end

  private

  def date_range(view, anchor)
    view == "week" ? [ anchor.beginning_of_week, anchor.end_of_week ] : [ Date.current, Date.current ]
  end

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end

  def resolve_staff_id
    return params[:staff_id].presence if @can_filter_staff
    return current_user.id if current_user.role_for.in?(PRODUCTION_ROLES)

    nil
  end

  def staff_options
    policy_scope(User).active.where(memberships: { role: PRODUCTION_ROLES, active: true }).order(:name)
  end
end
