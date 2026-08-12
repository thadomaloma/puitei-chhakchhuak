class DashboardController < ApplicationController
  def show
    authorize :dashboard, :show?

    @branch = current_branch
    @shop_setting = @branch.shop_setting
    orders = policy_scope(Order)
    confirmed_orders = orders.confirmed
    billable_orders = orders.billable
    tasks = policy_scope(ProductionTask)

    @orders_today_count = orders.where(ordered_on: Date.current).count
    @due_today_count = confirmed_orders.where(delivery_date: Date.current).count
    task_order_ids = tasks.joins(:order_item).select("order_items.order_id")
    unfinished_order_ids = tasks.joins(:order_item).where.not(status: %i[completed skipped]).select("order_items.order_id")
    @ready_count = confirmed_orders.where(id: task_order_ids).where.not(id: unfinished_order_ids).count

    @financial_access = policy(Payment).index?
    @expense_access = policy(Expense).index?
    if @financial_access
      payments = policy_scope(Payment).active
      @outstanding_balance = billable_orders.sum(:total_amount) - payments.where(order_id: billable_orders.select(:id)).sum(:amount)
      @monthly_revenue = payments.where(paid_on: Date.current.all_month).sum(:amount)
    end
    if @expense_access
      @monthly_expenses = policy_scope(Expense).active.where(incurred_on: Date.current.all_month).sum(:amount)
      @monthly_profit = @monthly_revenue - @monthly_expenses if @financial_access
    end

    @recent_orders = orders.includes(:customer, :payments, order_items: :production_tasks).recent_first.limit(6)
    @production_stages = production_summary(tasks)
    @upcoming_groups = upcoming_groups(confirmed_orders)
    @staff_workloads = staff_workloads(tasks)
    @low_stock_count = policy_scope(InventoryItem).low_stock.count
    @delivery_access = policy(Delivery).index?
  end

  private

  def production_summary(tasks)
    counts = tasks.group(:stage, :status).count
    unfinished = ->(stage) { counts.sum { |(task_stage, status), count| task_stage == stage && status.in?(%w[pending in_progress]) ? count : 0 } }
    [
      { key: "pending", icon: "clock", count: counts.sum { |(_stage, status), count| status == "pending" ? count : 0 } },
      { key: "cutting", icon: "production", count: unfinished.call("cutting") },
      { key: "embroidery", icon: "sparkles", count: unfinished.call("embroidery") },
      { key: "tailoring", icon: "needle", count: unfinished.call("tailoring") },
      { key: "finishing", icon: "check", count: unfinished.call("finishing") },
      { key: "ready", icon: "orders", count: @ready_count }
    ]
  end

  def upcoming_groups(orders)
    groups = [
      [ "trials", "ruler", orders.where(trial_date: Date.current), :neutral ],
      [ "deliveries", "calendar", orders.where(delivery_date: Date.current), :success ],
      [ "overdue", "warning", orders.where(delivery_date: ...Date.current).order(:delivery_date), :danger ]
    ]

    groups.map do |key, icon, scope, tone|
      { key: key, icon: icon, tone: tone, count: scope.count, orders: scope.includes(:customer).limit(3) }
    end
  end

  def staff_workloads(tasks)
    active_tasks = tasks.where.not(assigned_to_id: nil).where.not(status: %i[completed skipped]).joins(order_item: :order)
    active_counts = active_tasks.group(:assigned_to_id).count
    due_counts = active_tasks.where(orders: { delivery_date: Date.current }).group(:assigned_to_id).count
    overdue_counts = active_tasks.where("orders.delivery_date < ?", Date.current).group(:assigned_to_id).count
    max_count = [ active_counts.values.max.to_i, 1 ].max

    workforce_roles = Membership.roles.values_at("tailor", "cutting_staff", "embroidery_staff", "ironing_staff")
    policy_scope(User).active.where(memberships: { role: workforce_roles, active: true }).order(:name).limit(6).map do |staff|
      count = active_counts.fetch(staff.id, 0)
      {
        staff: staff,
        role: staff.role_for(current_shop),
        active: count,
        due: due_counts.fetch(staff.id, 0),
        overdue: overdue_counts.fetch(staff.id, 0),
        load_percentage: (count.fdiv(max_count) * 100).round
      }
    end
  end
end
