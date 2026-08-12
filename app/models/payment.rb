class Payment < ApplicationRecord
  tenant_owned_through :branch

  IMMUTABLE_ATTRIBUTES = %w[
    shop_id branch_id order_id received_by_id payment_number sequence_year sequence_number
    amount payment_method paid_on reference_number notes order_total_snapshot
    balance_before_snapshot balance_after_snapshot currency_snapshot
  ].freeze

  belongs_to :branch
  belongs_to :order
  belongs_to :received_by, class_name: "User", inverse_of: :received_payments
  belongs_to :voided_by, class_name: "User", optional: true, inverse_of: :voided_payments

  enum :payment_method, { cash: 0, card: 1, bank_transfer: 2, upi: 3, other: 4 }, validate: true

  before_validation :assign_defaults, on: :create, prepend: true

  validates :payment_number, :paid_on, :currency_snapshot, presence: true
  validates :payment_number, uniqueness: { scope: :shop_id }
  validates :sequence_number, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: %i[branch_id sequence_year] }
  validates :amount, numericality: { greater_than: 0 }
  validates :order_total_snapshot, :balance_before_snapshot, :balance_after_snapshot,
    numericality: { greater_than_or_equal_to: 0 }
  validates :reference_number, presence: true, unless: :cash?
  validates :void_reason, presence: true, if: :voided?
  validate :order_and_staff_belong_to_branch
  validate :order_accepts_payment, on: :create
  validate :does_not_exceed_balance, on: :create
  validate :snapshots_match_payment, on: :create
  validate :financial_details_are_immutable, on: :update
  validate :paid_on_is_not_in_future

  scope :active, -> { where(voided_at: nil) }
  scope :recent_first, -> { order(paid_on: :desc, id: :desc) }
  scope :search, lambda { |query|
    term = sanitize_sql_like(query.to_s.strip)
    return all if term.blank?

    joins(order: :customer).where(
      "payments.payment_number ILIKE :term OR orders.order_number ILIKE :term OR customers.full_name ILIKE :term",
      term: "%#{term}%"
    )
  }

  delegate :customer, to: :order

  def voided?
    voided_at.present?
  end

  def void!(actor, reason:)
    raise InvalidVoid, "Payment is already void" if voided?
    raise InvalidVoid, "Only an owner or manager can void a payment" unless tenant_role?(actor, :owner, :manager)
    raise InvalidVoid, "A reason is required" if reason.blank?
    raise InvalidVoid, "Manager must belong to the payment branch" unless tenant_branch_access?(actor)

    update!(voided_at: Time.current, voided_by: actor, void_reason: reason)
  end

  class InvalidVoid < StandardError; end

  private

  def assign_defaults
    self.branch ||= order&.branch
    self.paid_on ||= Date.current
    assign_financial_snapshots
    return if payment_number.present? || branch.blank?

    branch.with_lock do
      self.sequence_year = paid_on.year
      self.sequence_number = self.class.where(branch: branch, sequence_year: sequence_year).maximum(:sequence_number).to_i + 1
      self.payment_number = [ "RCT", branch.code, sequence_year, sequence_number.to_s.rjust(5, "0") ].join("-")
    end
  end

  def assign_financial_snapshots
    return unless order

    active_paid = order.payments.active.where.not(id: id).sum(:amount)
    self.order_total_snapshot = order.total_amount
    self.balance_before_snapshot = [ order.total_amount - active_paid, 0.to_d ].max
    self.balance_after_snapshot = [ balance_before_snapshot - amount.to_d, 0.to_d ].max
    self.currency_snapshot = order.currency
  end

  def order_and_staff_belong_to_branch
    errors.add(:order, "must belong to the payment branch") if order && branch && order.branch_id != branch_id
    errors.add(:received_by, "must belong to the payment branch") if received_by && branch && !tenant_branch_access?(received_by)
  end

  def order_accepts_payment
    errors.add(:order, "must be confirmed before receiving payment") unless order&.billable?
  end

  def does_not_exceed_balance
    errors.add(:amount, "cannot exceed the outstanding balance") if order && amount.to_d > order.balance_due
  end

  def snapshots_match_payment
    return if amount.blank? || balance_before_snapshot.blank? || balance_after_snapshot.blank?

    errors.add(:base, "Payment snapshot must match the receipt amount") unless balance_before_snapshot - amount == balance_after_snapshot
    errors.add(:base, "Payment snapshot must match the order total") if order && order_total_snapshot != order.total_amount
    errors.add(:base, "Payment snapshot currency must match the order") if order && currency_snapshot != order.currency
  end

  def financial_details_are_immutable
    changed = IMMUTABLE_ATTRIBUTES.select { |attribute| will_save_change_to_attribute?(attribute) }
    errors.add(:base, "Recorded payment details cannot be changed") if changed.any?
  end

  def paid_on_is_not_in_future
    errors.add(:paid_on, "cannot be in the future") if paid_on && paid_on > Date.current
  end
end
