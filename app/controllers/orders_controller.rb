class OrdersController < ApplicationController
  before_action :set_order, only: %i[show confirm job_card qr_code]
  before_action :set_form_options, only: %i[new create]

  def index
    authorize Order
    scoped_orders = policy_scope(Order)
    @order_metrics = order_metrics(scoped_orders)
    orders = scoped_orders.includes(:branch, :customer, :payments, order_items: :production_tasks).search(params[:query])
    orders = filter_orders(orders).recent_first
    @filters_active = params.values_at(:query, :status, :schedule).any?(&:present?)
    @pagy, @orders = pagy(:offset, orders, limit: 20)
  end

  def show
    authorize @order
    @inventory_items = policy_scope(InventoryItem).active.where("quantity_on_hand > quantity_reserved").alphabetical
    @production_staff = policy_scope(User).where(memberships: { branch_id: @order.branch_id, active: true }).active.to_a
    @delivery_candidate = Delivery.new(order_id: @order.id, branch_id: @order.branch_id, delivered_by: current_user)
  end

  def new
    @order = Order.new(ordered_on: Date.current)
    @order.customer = @customers.find_by(id: params[:customer_id])
    @order.delivery_date = Date.current + (@order.customer&.branch&.shop_setting&.default_delivery_days || current_branch.shop_setting.default_delivery_days).days
    @order.order_items.build
    authorize @order
  end

  def create
    @order = Order.new(order_params)
    @order.customer = @customers.find_by(id: order_params[:customer_id])
    @order.branch = @order.customer&.branch || current_branch
    @order.created_by = current_user
    authorize @order

    if @order.save
      redirect_to @order, notice: t("orders.created")
    else
      @order.order_items.build if @order.order_items.empty?
      render :new, status: :unprocessable_content
    end
  end

  def confirm
    authorize @order, :confirm?
    @order.confirm!
    redirect_to @order, notice: t("orders.confirmed")
  rescue ActiveRecord::RecordInvalid
    redirect_to @order, alert: @order.errors.full_messages.to_sentence
  end

  def job_card
    authorize @order, :job_card?
    render layout: "print"
  end

  def qr_code
    authorize @order, :qr_code?
    svg = RQRCode::QRCode.new(order_url(@order)).as_svg(
      color: "163c35", fill: "ffffff", module_size: 5, standalone: true, use_path: true, viewbox: true
    )
    send_data svg, type: "image/svg+xml", disposition: "inline"
  end

  private

  def set_order
    @order = policy_scope(Order)
      .includes(:branch, :created_by, :customer, delivery: :delivered_by, payments: [ :received_by, :voided_by ], order_items: [ :measurement, { design_selection: { design: { images_attachments: :blob } } }, { production_tasks: [ :assigned_to, :completed_by, { production_events: :actor } ] }, { stock_movements: :inventory_item }, { fabric_photos_attachments: :blob, design_references_attachments: :blob } ])
      .find(params[:id])
  end

  def set_form_options
    @customers = policy_scope(Customer).active.includes(branch: :shop_setting).order(:full_name)
    @measurements_by_customer = policy_scope(Measurement)
      .includes(measurement_profile: [ :customer, :measurement_template ])
      .order("measurement_profiles.customer_id", "measurement_profiles.name", version: :desc)
      .group_by { |measurement| measurement.measurement_profile.customer_id }
    @design_selections_by_customer = policy_scope(DesignSelection).active.where.not(status: :rejected)
      .includes(:design)
      .order(Arel.sql("(status = #{DesignSelection.statuses[:approved]}) DESC"), :selected_at)
      .group_by(&:customer_id)
  end

  def order_params
    params.require(:order).permit(
      :customer_id, :ordered_on, :trial_date, :delivery_date, :discount_amount, :notes,
      order_items_attributes: [
        :measurement_id, :design_selection_id, :garment_name, :quantity, :unit_price, :requires_embroidery,
        :special_instructions, { fabric_photos: [], design_references: [] }
      ]
    )
  end

  def filter_orders(orders)
    orders = orders.where(status: params[:status]) if params[:status].present? && Order.statuses.key?(params[:status])

    case params[:schedule]
    when "overdue" then orders.overdue
    when "due_soon" then orders.due_soon
    when "upcoming" then orders.upcoming
    else orders
    end
  end

  def order_metrics(orders)
    billable = orders.billable
    billed = billable.sum(:total_amount)
    paid = policy_scope(Payment).active.where(order_id: billable.select(:id)).sum(:amount)

    {
      total: orders.count,
      active: orders.confirmed.count,
      due_soon: orders.due_soon.count,
      outstanding: [ billed - paid, 0.to_d ].max
    }
  end
end
