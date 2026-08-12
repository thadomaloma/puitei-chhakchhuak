class DeliveriesController < ApplicationController
  before_action :set_order, only: %i[new create]
  before_action :set_delivery, only: %i[show receipt]

  def index
    authorize Delivery
    orders = policy_scope(Order)
    tasks = policy_scope(ProductionTask)
    task_order_ids = tasks.joins(:order_item).select("order_items.order_id")
    unfinished_order_ids = tasks.joins(:order_item).where.not(status: %i[completed skipped]).select("order_items.order_id")
    ready_base = orders.confirmed.where(id: task_order_ids).where.not(id: unfinished_order_ids)
    ready = ready_base.includes(:customer, :payments, order_items: :production_tasks).search(params[:query])
    deliveries = policy_scope(Delivery).includes(:delivered_by, order: [ :customer, :payments ]).search(params[:query])
    ready, deliveries = filter_delivery_views(ready, deliveries)
    deliveries = filter_delivery_history(deliveries).recent_first

    @ready_orders = ready.order(:delivery_date, :id).limit(50)
    @pagy, @deliveries = pagy(:offset, deliveries, limit: 20)
    @filtered_ready_count = ready.distinct.count
    @filtered_delivery_count = deliveries.count
    @ready_count = ready_base.distinct.count
    @overdue_count = ready_base.where(delivery_date: ...Date.current).distinct.count
    @delivered_today_count = policy_scope(Delivery).where(handed_over_at: Time.current.all_day).count
    ready_ids = ready_base.reorder(nil).select(:id)
    @outstanding_ready = orders.where(id: ready_ids).sum(:total_amount) - policy_scope(Payment).active.where(order_id: ready_ids).sum(:amount)
    @filters_active = params[:query].present? || params[:view].present? || params[:collection_method].present? || params[:from].present? || params[:to].present?
  end

  def new
    @delivery = @order.build_delivery(
      recipient_name: @order.customer.full_name,
      recipient_phone: @order.customer.phone_number,
      acknowledged_by: @order.customer.full_name,
      handed_over_at: Time.current
    )
    authorize @delivery
  end

  def create
    @delivery = @order.build_delivery(delivery_params.merge(delivered_by: current_user))
    authorize @delivery
    @delivery = @order.deliver!(actor: current_user, attributes: delivery_params)
    redirect_to @delivery, notice: t("deliveries.created")
  rescue ActiveRecord::RecordInvalid => error
    @delivery = error.record
    render :new, status: :unprocessable_content
  end

  def show
    authorize @delivery
  end

  def receipt
    authorize @delivery, :receipt?
    render layout: "print"
  end

  private

  def set_order
    @order = policy_scope(Order).includes(:branch, :customer, :payments, order_items: :production_tasks).find(params[:order_id])
  end

  def set_delivery
    @delivery = policy_scope(Delivery).includes(:branch, :delivered_by, proof_images_attachments: :blob, order: [ :customer, :order_items, :payments ]).find(params[:id])
  end

  def delivery_params
    params.require(:delivery).permit(
      :handed_over_at, :recipient_name, :recipient_phone, :collection_method, :recipient_relationship,
      :acknowledged_by, :recipient_acknowledged, :quality_checked, :garment_count_verified,
      :payment_status_confirmed, :packaging_complete, :notes, proof_images: []
    )
  end

  def filter_delivery_views(ready, deliveries)
    case params[:view]
    when "ready"
      [ ready, deliveries.none ]
    when "overdue"
      [ ready.where(delivery_date: ...Date.current), deliveries.none ]
    when "outstanding"
      outstanding_ready = ready.where(<<~SQL.squish)
        orders.total_amount > COALESCE((SELECT SUM(payments.amount) FROM payments WHERE payments.order_id = orders.id AND payments.voided_at IS NULL), 0)
      SQL
      [ outstanding_ready, deliveries.where("deliveries.balance_due_snapshot > 0") ]
    when "delivered"
      [ ready.none, deliveries ]
    else
      [ ready, deliveries ]
    end
  end

  def filter_delivery_history(deliveries)
    if Delivery.collection_methods.key?(params[:collection_method])
      deliveries = deliveries.where(collection_method: params[:collection_method])
    end
    deliveries = deliveries.where(handed_over_at: filter_date(params[:from]).beginning_of_day..) if filter_date(params[:from])
    deliveries = deliveries.where(handed_over_at: ..filter_date(params[:to]).end_of_day) if filter_date(params[:to])
    deliveries
  end

  def filter_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end
end
