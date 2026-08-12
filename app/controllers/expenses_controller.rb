class ExpensesController < ApplicationController
  before_action :set_expense, only: %i[show voucher approve void record_next]

  def index
    authorize Expense
    expenses = filtered_expenses
    @pagy, @expenses = pagy(:offset, expenses.includes(:branch, :recorded_by, :approved_by), limit: 25)

    scoped = policy_scope(Expense)
    @spent_today = scoped.active.where(incurred_on: Date.current).sum(:amount)
    @spent_this_month = scoped.active.where(incurred_on: Date.current.all_month).sum(:amount)
    @pending_count = scoped.pending_review.count
    @recurring_count = scoped.active.where.not(recurrence_interval: Expense.recurrence_intervals[:one_time]).count
  end

  def new
    @expense = current_branch.expenses.new(
      incurred_on: Date.current, payment_method: :cash, recurrence_interval: :one_time
    )
    authorize @expense
  end

  def create
    @expense = current_branch.expenses.new(
      expense_params.merge(recorded_by: current_user, currency: current_branch.shop_setting.currency)
    )
    authorize @expense

    if @expense.save
      redirect_to @expense, notice: t("expenses.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize @expense
  end

  def voucher
    authorize @expense, :voucher?
    render layout: "print"
  end

  def approve
    authorize @expense, :approve?
    @expense.approve!(current_user)
    redirect_to @expense, notice: t("expenses.approved")
  rescue Expense::InvalidApproval, ActiveRecord::RecordInvalid => error
    redirect_to @expense, alert: error.message
  end

  def void
    authorize @expense, :void?
    @expense.void!(current_user, reason: params.require(:expense).fetch(:void_reason))
    redirect_to @expense, notice: t("expenses.voided")
  rescue Expense::InvalidVoid, ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
    redirect_to @expense, alert: error.message
  end

  def record_next
    authorize @expense, :record_next?
    next_expense = @expense.record_next!(current_user)
    redirect_to next_expense, notice: t("expenses.next_recorded")
  rescue Expense::InvalidRecurrence, ActiveRecord::RecordInvalid => error
    redirect_to @expense, alert: error.message
  end

  def export
    authorize Expense, :export?
    expenses = filtered_expenses.reorder(incurred_on: :desc, id: :desc)
    send_data expense_csv(expenses), filename: "expenses-#{Date.current.iso8601}.csv", type: "text/csv; charset=utf-8"
  end

  private

  def set_expense
    @expense = policy_scope(Expense).includes(
      :branch, :recorded_by, :approved_by, :voided_by, :source_expense, :generated_expenses,
      receipts_attachments: :blob
    ).find(params[:id])
  end

  def filtered_expenses
    expenses = policy_scope(Expense).search(params[:query]).recent_first
    expenses = expenses.where(category: params[:category]) if Expense.categories.key?(params[:category])
    expenses = filter_status(expenses)
    expenses = filter_date(expenses, :from, :>=)
    filter_date(expenses, :to, :<=)
  end

  def filter_status(expenses)
    case params[:status]
    when "pending" then expenses.pending_review
    when "approved" then expenses.active
    when "voided" then expenses.where.not(voided_at: nil)
    else expenses
    end
  end

  def filter_date(expenses, key, operator)
    return expenses if params[key].blank?

    date = Date.iso8601(params[key])
    operator == :>= ? expenses.where("expenses.incurred_on >= ?", date) : expenses.where("expenses.incurred_on <= ?", date)
  rescue Date::Error
    expenses
  end

  def expense_params
    params.require(:expense).permit(
      :category, :amount, :incurred_on, :vendor, :payment_method, :reference_number,
      :description, :notes, :recurrence_interval, :next_due_on, receipts: []
    )
  end

  def expense_csv(expenses)
    rows = [ %w[expense_number date branch category description vendor payment_method reference amount currency status recorded_by approved_by] ]
    expenses.find_each do |expense|
      rows << [
          expense.expense_number, expense.incurred_on, safe_csv(expense.branch.name), expense.category,
          safe_csv(expense.description), safe_csv(expense.vendor), expense.payment_method,
          safe_csv(expense.reference_number), expense.amount, expense.currency, expense_status(expense),
          safe_csv(expense.recorded_by.name), safe_csv(expense.approved_by&.name)
      ]
    end
    rows.map { |row| row.map { |value| csv_cell(value) }.join(",") }.join("\r\n") + "\r\n"
  end

  def expense_status(expense)
    return "voided" if expense.voided?

    expense.approval_status
  end

  def safe_csv(value)
    text = value.to_s
    text.match?(/\A[=+\-@]/) ? "'#{text}" : text
  end

  def csv_cell(value)
    %Q("#{value.to_s.gsub('"', '""')}")
  end
end
