# frozen_string_literal: true

class BusinessReport
  SUMMARY_METRIC_I18N_KEYS = {
    revenue: "reports.revenue", expenses: "reports.expenses", profit: "reports.net_profit",
    orders: "reports.orders", order_value: "reports.order_value", average_order_value: "reports.average_order",
    outstanding: "reports.outstanding", customers: "reports.new_customers", deliveries: "reports.deliveries"
  }.freeze

  attr_reader :from, :to, :currency

  def initialize(orders:, payments:, expenses:, customers:, deliveries:, production_tasks:, users:, attendance_records:,
    from:, to:, currency:)
    @orders = orders
    @payments = payments
    @expenses = expenses
    @customers = customers
    @deliveries = deliveries
    @production_tasks = production_tasks
    @users = users
    @attendance_records = attendance_records
    @from = from
    @to = to
    @currency = currency
  end

  def summary
    @summary ||= begin
      revenue = period_payments.sum(:amount)
      expenses = period_expenses.sum(:amount)
      order_value = period_orders.sum(:total_amount)
      order_count = period_orders.count

      {
        revenue: revenue,
        expenses: expenses,
        profit: revenue - expenses,
        orders: order_count,
        order_value: order_value,
        average_order_value: order_count.positive? ? order_value / order_count : 0.to_d,
        outstanding: outstanding_balance,
        customers: period_customers.count,
        deliveries: period_deliveries.count
      }
    end
  end

  def trend
    @trend ||= begin
      revenue = monthly_totals(period_payments, :paid_on, :amount)
      expenses = monthly_totals(period_expenses, :incurred_on, :amount)
      orders = monthly_counts(period_orders, :ordered_on)

      report_months.map do |month|
        month_revenue = revenue.fetch(month, 0.to_d)
        month_expenses = expenses.fetch(month, 0.to_d)
        {
          month: month,
          revenue: month_revenue,
          expenses: month_expenses,
          profit: month_revenue - month_expenses,
          orders: orders.fetch(month, 0)
        }
      end
    end
  end

  def expense_categories
    @expense_categories ||= breakdown(
      period_expenses.group(:category).sum(:amount),
      total: summary[:expenses], enum: Expense.categories
    )
  end

  def payment_methods
    @payment_methods ||= breakdown(
      period_payments.group(:payment_method).sum(:amount),
      total: summary[:revenue], enum: Payment.payment_methods
    )
  end

  def staff_performance
    @staff_performance ||= begin
      completed = @production_tasks.where(completed_at: time_range).where.not(completed_by_id: nil).group(:completed_by_id).count
      active = @production_tasks.open.where.not(assigned_to_id: nil).group(:assigned_to_id).count
      hours = attendance_hours
      staff_ids = (completed.keys + active.keys + hours.keys).uniq
      staff = @users.where(id: staff_ids).index_by(&:id)

      staff_ids.filter_map do |staff_id|
        member = staff[staff_id]
        next unless member

        {
          staff: member,
          role: member.role_for,
          completed: completed.fetch(staff_id, 0),
          active: active.fetch(staff_id, 0),
          hours: hours.fetch(staff_id, 0.to_d)
        }
      end.sort_by { |row| [ -row[:completed], -row[:active], row[:staff].name.downcase ] }.first(10)
    end
  end

  def to_csv(advanced:)
    rows = [ safe_row([ "Puitei Chhakchhuak business report", "#{from.iso8601} to #{to.iso8601}", currency ]), [] ]
    append_summary_csv(rows)
    append_trend_csv(rows)
    append_advanced_csv(rows) if advanced
    rows.map { |row| row.map { |value| csv_cell(value) }.join(",") }.join("\r\n") + "\r\n"
  end

  private

  def append_summary_csv(rows)
    rows << [ I18n.t("reports.financial_summary") ]
    rows << [ I18n.t("reports.metric"), I18n.t("reports.value") ]
    SUMMARY_METRIC_I18N_KEYS.each do |metric, i18n_key|
      rows << safe_row([ I18n.t(i18n_key), summary.fetch(metric) ])
    end
    rows << []
  end

  def append_trend_csv(rows)
    rows << [ I18n.t("reports.trend") ]
    rows << [ I18n.t("reports.month"), I18n.t("reports.revenue"), I18n.t("reports.expenses"), I18n.t("reports.net_profit"), I18n.t("reports.orders") ]
    trend.each do |row|
      rows << safe_row([ row[:month].strftime("%B %Y"), row[:revenue], row[:expenses], row[:profit], row[:orders] ])
    end
    rows << []
  end

  def period_orders
    @period_orders ||= @orders.billable.where(ordered_on: from..to)
  end

  def period_payments
    @period_payments ||= @payments.active.where(paid_on: from..to)
  end

  def period_expenses
    @period_expenses ||= @expenses.active.where(incurred_on: from..to)
  end

  def period_customers
    @period_customers ||= @customers.where(created_at: time_range)
  end

  def period_deliveries
    @period_deliveries ||= @deliveries.where(handed_over_at: time_range)
  end

  def outstanding_balance
    value = period_orders.sum(:total_amount) - @payments.active.where(order_id: period_orders.select(:id)).sum(:amount)
    [ value, 0.to_d ].max
  end

  def report_months
    cursor = from.beginning_of_month
    last = to.beginning_of_month
    months = []
    while cursor <= last
      months << cursor
      cursor = cursor.next_month
    end
    months
  end

  def monthly_totals(relation, date_column, value_column)
    relation.group(Arel.sql("DATE_TRUNC('month', #{date_column})")).sum(value_column)
      .to_h { |key, value| [ key.to_date.beginning_of_month, value ] }
  end

  def monthly_counts(relation, date_column)
    relation.group(Arel.sql("DATE_TRUNC('month', #{date_column})")).count
      .to_h { |key, value| [ key.to_date.beginning_of_month, value ] }
  end

  def breakdown(values, total:, enum:)
    values.map do |key, value|
      enum_key = if key.is_a?(String) && enum.key?(key)
        key
      else
        enum.key(key.to_i)
      end
      {
        key: enum_key || key.to_s,
        value: value,
        percentage: total.positive? ? ((value / total) * 100).round : 0
      }
    end.sort_by { |row| -row[:value] }
  end

  def attendance_hours
    duration = Arel.sql("EXTRACT(EPOCH FROM (COALESCE(checked_out_at, CURRENT_TIMESTAMP) - checked_in_at)) / 3600.0")
    @attendance_records.where(work_date: from..to).group(:user_id).sum(duration)
  end

  def time_range
    from.beginning_of_day..to.end_of_day
  end

  def append_advanced_csv(rows)
    rows << [ I18n.t("reports.expense_breakdown") ]
    rows << [ I18n.t("expenses.category"), I18n.t("expenses.amount"), I18n.t("reports.percentage") ]
    expense_categories.each do |row|
      rows << safe_row([ I18n.t("expenses.categories.#{row[:key]}", default: row[:key].to_s.humanize), row[:value], row[:percentage] ])
    end
    rows << []

    rows << [ I18n.t("reports.payment_breakdown") ]
    rows << [ I18n.t("payments.method"), I18n.t("payments.amount"), I18n.t("reports.percentage") ]
    payment_methods.each do |row|
      rows << safe_row([ I18n.t("payments.methods.#{row[:key]}", default: row[:key].to_s.humanize), row[:value], row[:percentage] ])
    end
    rows << []

    rows << [ I18n.t("reports.staff_performance") ]
    rows << [ I18n.t("reports.staff_member"), I18n.t("staff.role"), I18n.t("reports.completed_tasks"), I18n.t("reports.active_tasks"), I18n.t("reports.attendance_hours") ]
    staff_performance.each do |row|
      rows << safe_row([ row[:staff].name, row[:role].humanize, row[:completed], row[:active], row[:hours] ])
    end
  end

  def safe_row(values)
    values.map do |value|
      value.is_a?(String) && value.match?(/\A[=+\-@]/) ? "'#{value}" : value
    end
  end

  def csv_cell(value)
    formatted = value.is_a?(Numeric) && !value.is_a?(Integer) ? format("%.2f", value) : value.to_s
    %Q("#{formatted.gsub('"', '""')}")
  end
end
