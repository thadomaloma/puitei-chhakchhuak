class ReportsController < ApplicationController
  MAX_RANGE_DAYS = 366

  before_action :set_period

  def index
    authorize :report, :index?
    set_report
  end

  def export
    authorize :report, :export?
    set_report
    send_data @report.to_csv(advanced: true),
      filename: "business-report-#{@from.iso8601}-#{@to.iso8601}.csv",
      type: "text/csv; charset=utf-8"
  end

  private

  def set_period
    @from = parsed_date(params[:from]) || 29.days.ago.to_date
    @to = parsed_date(params[:to]) || Date.current
    @from, @to = @to, @from if @from > @to
    @to = [ @to, Date.current ].min
    @from = [ @from, @to ].min
    if (@to - @from).to_i > MAX_RANGE_DAYS
      @from = @to - MAX_RANGE_DAYS.days
      @range_limited = true
    end
  end

  def set_report
    @report = BusinessReport.new(
      orders: policy_scope(Order), payments: policy_scope(Payment), expenses: policy_scope(Expense),
      customers: policy_scope(Customer), deliveries: policy_scope(Delivery),
      production_tasks: policy_scope(ProductionTask), users: policy_scope(User),
      attendance_records: policy_scope(AttendanceRecord), from: @from, to: @to,
      currency: current_branch.shop_setting.currency
    )
  end

  def parsed_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end
end
