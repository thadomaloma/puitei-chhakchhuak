class PaymentsController < ApplicationController
  before_action :set_order, only: %i[new create]
  before_action :set_payment, only: %i[show receipt void]

  def index
    authorize Payment
    payments = policy_scope(Payment).includes(:branch, :received_by, order: :customer).search(params[:query]).recent_first
    payments = filter_payments(payments)
    @filtered_count = payments.count
    @pagy, @payments = pagy(:offset, payments, limit: 25)

    scoped_payments = policy_scope(Payment)
    @collected_today = scoped_payments.active.where(paid_on: Date.current).sum(:amount)
    @collected_month = scoped_payments.active.where(paid_on: Date.current.beginning_of_month..Date.current).sum(:amount)
    @voided_count = scoped_payments.where.not(voided_at: nil).count
    receivables = receivable_orders.search(params[:query])
    @receivable_count = receivables.count.length
    @receivable_orders = receivables.includes(:customer, :payments, :order_items).order(:delivery_date, :id).limit(8)
    @outstanding_total = receivable_orders.pluck("orders.total_amount", Arel.sql("COALESCE(SUM(active_receipts.amount), 0)")).sum { |total, paid| total - paid }
    @filters_active = params[:query].present? || params[:status].present? || params[:payment_method].present? || params[:from].present? || params[:to].present?
  end

  def new
    @payment = @order.payments.new(
      amount: @order.balance_due,
      payment_method: :cash,
      paid_on: Date.current,
      received_by: current_user,
      branch: @order.branch
    )
    authorize @payment
  end

  def show
    authorize @payment
  end

  def create
    @payment = @order.payments.new(payment_params.merge(received_by: current_user))
    authorize @payment
    payment = @order.record_payment(payment_params.merge(received_by: current_user))
    redirect_to payment, notice: t("payments.created")
  rescue ActiveRecord::RecordInvalid => error
    @payment = error.record
    render :new, status: :unprocessable_content
  end

  def receipt
    authorize @payment, :receipt?
    render layout: "print"
  end

  def void
    authorize @payment, :void?
    @payment.void!(current_user, reason: params.require(:payment).fetch(:void_reason))
    redirect_to @payment, notice: t("payments.voided")
  rescue Payment::InvalidVoid, ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
    redirect_to @payment, alert: error.message
  end

  private

  def set_order
    @order = policy_scope(Order).includes(:branch, :customer, :payments, :order_items).find(params[:order_id])
  end

  def set_payment
    @payment = policy_scope(Payment).includes(:branch, :received_by, :voided_by, order: :customer).find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(:amount, :payment_method, :paid_on, :reference_number, :notes)
  end

  def filter_payments(payments)
    payments = case params[:status]
    when "voided" then payments.where.not(voided_at: nil)
    when "all" then payments
    else payments.active
    end
    payments = payments.where(payment_method: params[:payment_method]) if Payment.payment_methods.key?(params[:payment_method])
    payments = payments.where(paid_on: filter_date(params[:from])..) if filter_date(params[:from])
    payments = payments.where(paid_on: ..filter_date(params[:to])) if filter_date(params[:to])
    payments
  end

  def receivable_orders
    policy_scope(Order).with_balance
  end

  def filter_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end
end
