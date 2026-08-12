class ProductionsController < ApplicationController
  DUE_SOON_DAYS = 3

  def index
    authorize :production, :index?
    scoped_tasks = policy_scope(ProductionTask)
    set_production_metrics(scoped_tasks)
    tasks = scoped_tasks
      .includes(:assigned_to, :completed_by, production_events: :actor,
        order_item: [ :production_tasks, { order: [ :customer, { branch: :users } ] },
          { fabric_photos_attachments: :blob, design_references_attachments: :blob } ])
      .search(params[:query])
    tasks = filter_tasks(tasks).queue_order
    @filtered_count = tasks.count
    @pagy, @tasks = pagy(:offset, tasks, limit: 30)
    @active_staff_by_branch = @tasks.map(&:branch).uniq.to_h { |branch| [ branch.id, branch.users.select(&:active?) ] }
    @filters_active = params.values_at(:query, :stage, :status, :urgency, :assignment).any?(&:present?) || params[:mine] == "1"
  end

  private

  def filter_tasks(tasks)
    tasks = tasks.where(stage: params[:stage]) if params[:stage].present? && ProductionTask.stages.key?(params[:stage])
    if params[:status].present? && ProductionTask.statuses.key?(params[:status])
      tasks = tasks.where(status: params[:status])
    elsif params[:status] != "all"
      tasks = tasks.open
    end
    tasks = filter_by_urgency(tasks)

    case params[:assignment]
    when "mine" then tasks.where(assigned_to: current_user)
    when "unassigned" then tasks.where(assigned_to_id: nil)
    else params[:mine] == "1" ? tasks.where(assigned_to: current_user) : tasks
    end
  end

  def filter_by_urgency(tasks)
    case params[:urgency]
    when "overdue" then tasks.open.where("orders.delivery_date < ?", Date.current)
    when "today" then tasks.open.where(orders: { delivery_date: Date.current })
    when "due_soon" then tasks.open.where(orders: { delivery_date: Date.current..DUE_SOON_DAYS.days.from_now.to_date })
    when "this_week" then tasks.open.where(orders: { delivery_date: Date.current..7.days.from_now.to_date })
    else tasks
    end
  end

  def set_production_metrics(tasks)
    queue = tasks.joins(order_item: :order)
    open_tasks = queue.open
    @in_progress_count = queue.in_progress.count
    @unassigned_count = queue.pending.where(assigned_to_id: nil).count
    @due_today_count = open_tasks.where(orders: { delivery_date: Date.current }).count
    @overdue_count = open_tasks.where("orders.delivery_date < ?", Date.current).count
    @open_count = open_tasks.count
    @stage_counts = open_tasks.group(:stage).count
    @staff_workload = staff_workload(open_tasks)
  end

  def staff_workload(open_tasks)
    active_counts = open_tasks.where.not(assigned_to_id: nil).group(:assigned_to_id).count
    return [] if active_counts.empty?

    staff_by_id = User.where(id: active_counts.keys).index_by(&:id)
    active_counts.map { |staff_id, count| { staff: staff_by_id[staff_id], active: count } }
      .sort_by { |row| -row[:active] }
  end
end
