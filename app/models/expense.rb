class Expense < ApplicationRecord
  tenant_owned_through :branch

  IMMUTABLE_ATTRIBUTES = %w[
    shop_id branch_id recorded_by_id source_expense_id expense_number sequence_year sequence_number
    category amount currency incurred_on vendor payment_method reference_number description notes
    recurrence_interval next_due_on
  ].freeze
  RECEIPT_TYPES = %w[image/jpeg image/png image/webp application/pdf].freeze

  belongs_to :branch
  belongs_to :recorded_by, class_name: "User", inverse_of: :recorded_expenses
  belongs_to :approved_by, class_name: "User", optional: true, inverse_of: :approved_expenses
  belongs_to :voided_by, class_name: "User", optional: true, inverse_of: :voided_expenses
  belongs_to :source_expense, class_name: "Expense", optional: true, inverse_of: :generated_expenses
  has_many :generated_expenses, class_name: "Expense", foreign_key: :source_expense_id,
    dependent: :restrict_with_error, inverse_of: :source_expense
  has_many_attached :receipts

  enum :category, {
    rent: 0, salary: 1, utilities: 2, transport: 3, material_purchase: 4,
    maintenance: 5, equipment: 6, marketing: 7, taxes: 8, other: 9
  }, validate: true, prefix: :category
  enum :payment_method, { cash: 0, card: 1, bank_transfer: 2, upi: 3, other: 4 }, validate: true, prefix: :payment
  enum :approval_status, { pending: 0, approved: 1 }, validate: true, prefix: :approval
  enum :recurrence_interval, { one_time: 0, weekly: 1, monthly: 2, quarterly: 3, yearly: 4 }, validate: true

  before_validation :assign_defaults, on: :create
  before_validation :assign_approval, on: :create
  before_validation :assign_next_due_date, on: :create

  validates :expense_number, :currency, :incurred_on, :description, presence: true
  validates :expense_number, uniqueness: { scope: :shop_id }
  validates :sequence_number, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: %i[branch_id sequence_year] }
  validates :amount, numericality: { greater_than: 0 }
  validates :reference_number, presence: true, unless: :payment_cash?
  validates :approved_at, :approved_by, presence: true, if: :approval_approved?
  validates :void_reason, :voided_by, presence: true, if: :voided?
  validate :incurred_on_is_not_in_future
  validate :people_belong_to_branch
  validate :recurrence_is_consistent
  validate :financial_details_are_immutable, on: :update
  validate :acceptable_receipts

  scope :active, -> { approval_approved.where(voided_at: nil) }
  scope :pending_review, -> { approval_pending.where(voided_at: nil) }
  scope :recent_first, -> { order(incurred_on: :desc, id: :desc) }
  scope :search, lambda { |query|
    term = sanitize_sql_like(query.to_s.strip)
    return all if term.blank?

    where(
      "expenses.expense_number ILIKE :term OR expenses.description ILIKE :term OR expenses.vendor ILIKE :term OR expenses.reference_number ILIKE :term",
      term: "%#{term}%"
    )
  }

  def voided?
    voided_at.present?
  end

  def recurring?
    !one_time?
  end

  def approve!(actor)
    raise InvalidApproval, "Expense is already approved" if approval_approved?
    raise InvalidApproval, "Void expenses cannot be approved" if voided?
    ensure_manager!(actor, InvalidApproval)

    update!(approval_status: :approved, approved_by: actor, approved_at: Time.current)
  end

  def void!(actor, reason:)
    raise InvalidVoid, "Expense is already void" if voided?
    raise InvalidVoid, "A reason is required" if reason.blank?
    ensure_manager!(actor, InvalidVoid)

    update!(voided_at: Time.current, voided_by: actor, void_reason: reason)
  end

  def record_next!(actor)
    raise InvalidRecurrence, "This is not a recurring expense" unless recurring?
    raise InvalidRecurrence, "Only approved active expenses can recur" unless approval_approved? && !voided?
    raise InvalidRecurrence, "The next occurrence is not due yet" if next_due_on > Date.current
    raise InvalidRecurrence, "Staff member cannot record this branch expense" unless tenant_branch_access?(actor)

    with_lock do
      raise InvalidRecurrence, "The next occurrence has already been recorded" if generated_expenses.exists?(incurred_on: next_due_on)

      self.class.create!(
        branch: branch, recorded_by: actor, source_expense: self, category: category, amount: amount,
        currency: currency, incurred_on: next_due_on, vendor: vendor, payment_method: payment_method,
        reference_number: reference_number, description: description, notes: notes,
        recurrence_interval: recurrence_interval
      )
    end
  end

  class InvalidApproval < StandardError; end
  class InvalidVoid < StandardError; end
  class InvalidRecurrence < StandardError; end

  private

  def assign_defaults
    self.incurred_on ||= Date.current
    self.currency ||= branch&.shop_setting&.currency
    return if expense_number.present? || branch.blank?

    branch.with_lock do
      self.sequence_year = incurred_on.year
      self.sequence_number = self.class.where(branch: branch, sequence_year: sequence_year).maximum(:sequence_number).to_i + 1
      self.expense_number = [ "EXP", branch.code, sequence_year, sequence_number.to_s.rjust(5, "0") ].join("-")
    end
  end

  def assign_approval
    return unless tenant_role?(recorded_by, :owner, :manager)

    self.approval_status = :approved
    self.approved_by ||= recorded_by
    self.approved_at ||= Time.current
  end

  def assign_next_due_date
    self.next_due_on = nil if one_time?
    self.next_due_on ||= next_date_after(incurred_on) if recurring? && incurred_on
  end

  def next_date_after(date)
    case recurrence_interval
    when "weekly" then date + 1.week
    when "monthly" then date.next_month
    when "quarterly" then date.next_month(3)
    when "yearly" then date.next_year
    end
  end

  def ensure_manager!(actor, error_class)
    raise error_class, "Only an owner or manager can perform this action" unless tenant_role?(actor, :owner, :manager)
    raise error_class, "Manager must belong to the expense branch" unless tenant_branch_access?(actor)
  end

  def incurred_on_is_not_in_future
    errors.add(:incurred_on, "cannot be in the future") if incurred_on && incurred_on > Date.current
  end

  def people_belong_to_branch
    { recorded_by: recorded_by, approved_by: approved_by, voided_by: voided_by }.each do |name, person|
      errors.add(name, "must belong to the expense branch") if person && branch && !tenant_branch_access?(person)
    end
    errors.add(:source_expense, "must belong to the expense branch") if source_expense && branch && source_expense.branch_id != branch_id
  end

  def recurrence_is_consistent
    if recurring?
      errors.add(:next_due_on, "must be after the expense date") unless next_due_on && incurred_on && next_due_on > incurred_on
    elsif next_due_on.present?
      errors.add(:next_due_on, "must be blank for a one-time expense")
    end
  end

  def financial_details_are_immutable
    changed = IMMUTABLE_ATTRIBUTES.select { |attribute| will_save_change_to_attribute?(attribute) }
    errors.add(:base, "Recorded expense details cannot be changed") if changed.any?
  end

  def acceptable_receipts
    receipts.each do |receipt|
      errors.add(:receipts, "must be JPEG, PNG, WebP, or PDF files") unless receipt.blob.content_type.in?(RECEIPT_TYPES)
      errors.add(:receipts, "must each be smaller than 8 MB") if receipt.blob.byte_size > 8.megabytes
    end
  end
end
