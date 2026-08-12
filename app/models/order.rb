class Order < ApplicationRecord
  tenant_owned_through :branch
  belongs_to :branch
  belongs_to :customer
  belongs_to :created_by, class_name: "User"
  has_many :order_items, dependent: :restrict_with_error, inverse_of: :order
  has_many :payments, -> { order(paid_on: :desc, id: :desc) }, dependent: :restrict_with_error, inverse_of: :order
  has_one :delivery, dependent: :restrict_with_error, inverse_of: :order

  accepts_nested_attributes_for :order_items,
    reject_if: ->(attributes) { attributes["garment_name"].blank? && attributes["measurement_id"].blank? }

  enum :status, { draft: 0, confirmed: 1, cancelled: 2, delivered: 3 }, validate: true

  before_validation :assign_defaults, on: :create

  validates :order_number, :ordered_on, :delivery_date, presence: true
  validates :order_number, uniqueness: { scope: :shop_id }
  validates :sequence_number, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: %i[branch_id sequence_year] }
  validate :customer_belongs_to_branch
  validate :dates_are_in_order
  validate :has_at_least_one_item, if: :confirmed?
  validate :discount_is_valid
  validate :garments_are_priced, if: :confirmed?
  validate :finalized_pricing_is_immutable, on: :update

  scope :recent_first, -> { order(ordered_on: :desc, id: :desc) }
  scope :billable, -> { where(status: %i[confirmed delivered]) }
  scope :due_soon, -> { where(status: :confirmed).where(delivery_date: Date.current..7.days.from_now.to_date) }
  scope :overdue, -> { where(status: :confirmed).where(delivery_date: ...Date.current) }
  scope :upcoming, -> { where(status: :confirmed).where(delivery_date: 8.days.from_now.to_date..) }
  scope :with_balance, -> {
    billable
      .joins("LEFT JOIN payments AS active_receipts ON active_receipts.order_id = orders.id AND active_receipts.voided_at IS NULL")
      .group("orders.id")
      .having("orders.total_amount > COALESCE(SUM(active_receipts.amount), 0)")
  }
  scope :search, lambda { |query|
    term = sanitize_sql_like(query.to_s.strip)
    return all if term.blank?

    joins(:customer).where(
      "orders.order_number ILIKE :term OR customers.full_name ILIKE :term OR customers.phone_number ILIKE :term OR customers.whatsapp_number ILIKE :term",
      term: "%#{term}%"
    )
  }

  def confirm!
    with_lock do
      self.status = :confirmed
      self.confirmed_at = Time.current
      finalize_pricing
      save!
      order_items.each(&:create_production_tasks!)
    end
  end

  def editable?
    draft?
  end

  def billable?
    confirmed? || delivered?
  end

  def production_progress
    tasks = order_items.flat_map(&:production_tasks)
    return 0 if tasks.empty?

    finished = tasks.count { |task| task.completed? || task.skipped? }
    (finished.fdiv(tasks.length) * 100).round
  end

  def production_complete?
    billable? && order_items.any? && order_items.all?(&:production_complete?)
  end

  def estimated_subtotal
    order_items.sum(&:line_total)
  end

  def paid_amount
    return payments.reject(&:voided?).sum(&:amount) if payments.loaded?

    payments.active.sum(:amount)
  end

  def balance_due
    [ total_amount - paid_amount, 0.to_d ].max
  end

  def payment_status
    return "paid" if total_amount.positive? && balance_due.zero?
    return "partial" if paid_amount.positive?

    "unpaid"
  end

  def record_payment(attributes)
    with_lock { payments.create!(attributes) }
  end

  def deliver!(actor:, attributes:)
    with_lock do
      record = build_delivery(attributes.merge(branch: branch, delivered_by: actor))
      record.save!
      update!(status: :delivered)
      record
    end
  end

  private

  def assign_defaults
    self.ordered_on ||= Date.current
    self.discount_amount ||= 0
    self.delivery_date ||= ordered_on + (branch&.shop_setting&.default_delivery_days || 14).days
    return if order_number.present? || branch.blank?

    branch.with_lock do
      self.sequence_year = ordered_on.year
      self.sequence_number = self.class.where(branch: branch, sequence_year: sequence_year).maximum(:sequence_number).to_i + 1
      prefix = branch.shop_setting&.invoice_prefix.presence || "ORD"
      self.order_number = [ prefix, branch.code, sequence_year, sequence_number.to_s.rjust(5, "0") ].join("-")
    end
  end

  def customer_belongs_to_branch
    errors.add(:customer, "must belong to the order branch") if customer && branch && customer.branch_id != branch_id
  end

  def dates_are_in_order
    return if ordered_on.blank? || delivery_date.blank?

    errors.add(:delivery_date, "cannot be before the order date") if delivery_date < ordered_on
    errors.add(:trial_date, "must be between the order and delivery dates") if trial_date && !trial_date.between?(ordered_on, delivery_date)
  end

  def has_at_least_one_item
    errors.add(:order_items, "must include at least one garment") if order_items.reject(&:marked_for_destruction?).empty?
  end

  def discount_is_valid
    return if discount_amount.blank?

    errors.add(:discount_amount, "cannot be negative") if discount_amount.negative?
    errors.add(:discount_amount, "cannot exceed the subtotal") if discount_amount > estimated_subtotal
  end

  def garments_are_priced
    errors.add(:order_items, "must have a positive price for every garment") if order_items.any? { |item| item.unit_price.to_d <= 0 }
  end

  def finalize_pricing
    self.currency = branch.shop_setting.currency
    self.subtotal_amount = estimated_subtotal
    self.tax_rate_snapshot = branch.shop_setting.tax_rate
    taxable_amount = subtotal_amount - discount_amount
    self.tax_amount = (taxable_amount * tax_rate_snapshot / 100).round(2)
    self.total_amount = taxable_amount + tax_amount
    self.pricing_finalized_at = Time.current
  end

  def finalized_pricing_is_immutable
    return if attribute_in_database("pricing_finalized_at").blank?

    attributes = %w[currency subtotal_amount discount_amount tax_rate_snapshot tax_amount total_amount pricing_finalized_at]
    errors.add(:base, "Finalized order pricing cannot be changed") if attributes.any? { |attribute| will_save_change_to_attribute?(attribute) }
  end
end
