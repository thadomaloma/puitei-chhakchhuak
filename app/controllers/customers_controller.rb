class CustomersController < ApplicationController
  before_action :set_customer, only: %i[show edit update destroy]
  before_action :set_available_branches, only: %i[new create]

  def index
    authorize Customer
    customers = policy_scope(Customer).with_attached_profile_photo.search(params[:query]).recent_first
    customers = filter_customers(customers)
    @total_customer_count = policy_scope(Customer).count
    @filtered_customer_count = customers.count
    @filters_active = customer_filters_active?
    @pagy, @customers = pagy(:offset, customers, limit: 20)
    @customer_metrics = customer_directory_metrics(@customers)
  end

  def show
    authorize @customer
    @measurement_access = policy(MeasurementProfile).index?
    @financial_access = policy(Payment).index?
    @measurement_profiles = if @measurement_access
      policy_scope(MeasurementProfile)
        .where(customer: @customer)
        .includes(:measurement_template, measurements: [ :created_by, :order_items, { photos_attachments: :blob } ])
        .order(active: :desc, created_at: :desc)
    else
      MeasurementProfile.none
    end
    customer_orders = policy_scope(Order).where(customer: @customer)
    @orders = customer_orders.includes(:order_items).recent_first.limit(10)
    @payments = if @financial_access
      policy_scope(Payment).joins(:order).where(orders: { customer_id: @customer.id }).includes(:order).order(paid_on: :desc, id: :desc).limit(10)
    else
      Payment.none
    end
    @orders_with_balance = @financial_access ? customer_orders.with_balance.includes(:order_items).order(:delivery_date, :id) : Order.none
    @customer_summary = customer_summary(customer_orders)
    @design_selection_access = policy(DesignSelection).index?
    if @design_selection_access
      selection_scope = policy_scope(DesignSelection).where(customer: @customer)
      @design_selection_counts = selection_scope.active.group(:status).count
      @active_design_selection_count = @design_selection_counts.values.sum
      filtered_scope = if params[:selection_status] == "archived"
        selection_scope.where.not(archived_at: nil)
      else
        active_scope = selection_scope.active
        DesignSelection.statuses.key?(params[:selection_status]) ? active_scope.where(status: params[:selection_status]) : active_scope
      end
      @design_selection_pagy, @design_selections = pagy(
        :offset,
        filtered_scope.includes(:selected_by, design: { images_attachments: :blob }).recent_first,
        limit: 12,
        page_key: "selection_page"
      )
    else
      @design_selection_counts = {}
      @active_design_selection_count = 0
      @design_selections = DesignSelection.none
    end
    @activity = customer_activity
    @tab = available_customer_tabs.include?(params[:tab]) ? params[:tab] : "overview"
  end

  def new
    @customer = Customer.new(branch: current_branch, preferred_language: current_branch.locale)
    authorize @customer
  end

  def create
    @customer = Customer.new(customer_params)
    @customer.branch = selected_branch
    authorize @customer

    if @customer.save
      redirect_to @customer, notice: t("customers.created")
    else
      @duplicate_customer = find_duplicate_customer
      @customer.errors.delete(:phone_number) if @duplicate_customer
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @customer
  end

  def update
    authorize @customer

    attributes = customer_params.except(:branch_id, :remove_profile_photo)
    if @customer.update(attributes)
      @customer.profile_photo.purge if remove_profile_photo?
      redirect_to @customer, notice: t("customers.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @customer
    @customer.archive!
    redirect_to customers_path, notice: t("customers.archived")
  end

  private

  def set_customer
    @customer = policy_scope(Customer).find(params[:id])
  end

  def set_available_branches
    @available_branches = policy_scope(Branch).active.order(:name)
  end

  def selected_branch
    return current_branch unless current_user.owner?

    @available_branches.find(customer_params[:branch_id].presence || current_branch.id)
  end

  def customer_params
    params.require(:customer).permit(
      :branch_id, :full_name, :phone_number, :whatsapp_number, :email, :gender,
      :date_of_birth, :address, :city, :notes, :preferred_language, :profile_photo, :remove_profile_photo
    )
  end

  def filter_customers(customers)
    customers = case params[:status]
    when "archived" then customers.where(active: false)
    when "all" then customers
    else customers.active
    end
    customers = customers.where(gender: params[:gender]) if params[:gender].present? && Customer.genders.key?(params[:gender])
    customers = customers.where(created_at: 30.days.ago..) if params[:activity] == "recently_added"
    if params[:activity] == "recently_ordered"
      customers = customers.where(id: policy_scope(Order).where(ordered_on: 90.days.ago.to_date..).select(:customer_id))
    end
    if params[:outstanding] == "1"
      customers = customers.where(id: outstanding_orders.select(:customer_id))
    end
    customers
  end

  def outstanding_orders
    policy_scope(Order).billable.where(<<~SQL.squish)
      orders.total_amount > (
        SELECT COALESCE(SUM(payments.amount), 0)
        FROM payments
        WHERE payments.order_id = orders.id AND payments.voided_at IS NULL
      )
    SQL
  end

  def customer_filters_active?
    params[:query].present? || params[:status].present? || params[:gender].present? ||
      params[:activity].present? || params[:outstanding] == "1"
  end

  def customer_directory_metrics(customers)
    ids = customers.map(&:id)
    metrics = ids.index_with { { order_count: 0, last_order_on: nil, outstanding_balance: 0.to_d } }
    return metrics if ids.empty?

    policy_scope(Order).where(customer_id: ids).group(:customer_id).pluck(
      :customer_id, Arel.sql("COUNT(*)"), Arel.sql("MAX(ordered_on)")
    ).each do |customer_id, count, last_order_on|
      metrics[customer_id][:order_count] = count
      metrics[customer_id][:last_order_on] = last_order_on
    end

    totals = policy_scope(Order).billable.where(customer_id: ids).group(:customer_id).sum(:total_amount)
    paid = policy_scope(Payment).where(voided_at: nil).joins(:order).where(orders: { customer_id: ids }).group("orders.customer_id").sum(:amount)
    ids.each { |id| metrics[id][:outstanding_balance] = totals.fetch(id, 0.to_d) - paid.fetch(id, 0.to_d) }
    metrics
  end

  def customer_summary(customer_orders)
    billable = customer_orders.billable
    total_value = billable.sum(:total_amount)
    total_paid = @financial_access ? policy_scope(Payment).where(voided_at: nil).joins(:order).where(orders: { customer_id: @customer.id }).sum(:amount) : 0.to_d
    {
      total_orders: customer_orders.count,
      total_spent: total_paid,
      outstanding_balance: total_value - total_paid,
      last_order: customer_orders.recent_first.first,
      upcoming_delivery: customer_orders.where(status: :confirmed, delivery_date: Date.current..).minimum(:delivery_date),
      measurement_profiles: @measurement_profiles.size
    }
  end

  def customer_activity
    events = [ { type: :customer, occurred_at: @customer.created_at, label: t("customers.activity_created") } ]
    @measurement_profiles.flat_map(&:measurements).first(8).each do |measurement|
      events << { type: :measurement, occurred_at: measurement.created_at, label: t("customers.activity_measurement", profile: measurement.measurement_profile.name, version: measurement.version) }
    end
    @orders.each do |order|
      events << { type: :order, occurred_at: order.created_at, label: t("customers.activity_order", number: order.order_number) }
    end
    @payments.each do |payment|
      events << { type: :payment, occurred_at: payment.created_at, label: t("customers.activity_payment", amount: helpers.money(payment.amount, payment.order.currency)) }
    end
    events.sort_by { |event| event[:occurred_at] }.reverse.first(10)
  end

  def available_customer_tabs
    tabs = %w[overview orders notes]
    tabs << "measurements" if @measurement_access
    tabs << "gallery" if @measurement_access || @design_selection_access
    tabs << "payments" if @financial_access
    tabs
  end

  def remove_profile_photo?
    ActiveModel::Type::Boolean.new.cast(customer_params[:remove_profile_photo]) && @customer.profile_photo.attached?
  end

  def find_duplicate_customer
    return unless @customer.errors[:phone_number].present?

    policy_scope(Customer).find_by(branch_id: @customer.branch_id, phone_number: @customer.phone_number)
  end
end
