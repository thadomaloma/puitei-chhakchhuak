class Delivery < ApplicationRecord
  tenant_owned_through :branch

  IMMUTABLE_ATTRIBUTES = %w[
    shop_id branch_id order_id delivered_by_id delivery_number sequence_year sequence_number handed_over_at
    recipient_name recipient_phone collection_method recipient_relationship acknowledged_by
    recipient_acknowledged quality_checked garment_count_verified payment_status_confirmed packaging_complete
    total_amount_snapshot paid_amount_snapshot balance_due_snapshot currency notes
  ].freeze

  belongs_to :branch
  belongs_to :order, inverse_of: :delivery
  belongs_to :delivered_by, class_name: "User", inverse_of: :deliveries
  has_many_attached :proof_images

  enum :collection_method, { customer_pickup: 0, authorized_pickup: 1, courier: 2 }, validate: true

  before_validation :assign_defaults, on: :create, prepend: true

  validates :delivery_number, :handed_over_at, :recipient_name, :acknowledged_by, :currency, presence: true
  validates :delivery_number, uniqueness: { scope: :shop_id }
  validates :order_id, uniqueness: true
  validates :sequence_number, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: %i[branch_id sequence_year] }
  validates :total_amount_snapshot, :paid_amount_snapshot, :balance_due_snapshot,
    numericality: { greater_than_or_equal_to: 0 }
  validates :recipient_acknowledged, :quality_checked, :garment_count_verified, :payment_status_confirmed, :packaging_complete,
    acceptance: true
  validate :order_and_staff_belong_to_branch
  validate :order_is_ready, on: :create
  validate :actor_can_complete_handover, on: :create
  validate :outstanding_balance_requires_manager, on: :create
  validate :handover_time_is_valid
  validate :snapshots_match_order, on: :create
  validate :recorded_details_are_immutable, on: :update
  validate :acceptable_proof_images
  before_destroy :prevent_destruction

  scope :recent_first, -> { order(handed_over_at: :desc, id: :desc) }
  scope :search, lambda { |query|
    term = sanitize_sql_like(query.to_s.strip)
    return all if term.blank?

    joins(order: :customer).where(
      "deliveries.delivery_number ILIKE :term OR orders.order_number ILIKE :term OR customers.full_name ILIKE :term OR deliveries.recipient_name ILIKE :term",
      term: "%#{term}%"
    )
  }

  delegate :customer, to: :order

  private

  def assign_defaults
    self.branch ||= order&.branch
    self.handed_over_at ||= Time.current
    self.recipient_name ||= order&.customer&.full_name
    self.recipient_phone ||= order&.customer&.phone_number
    self.acknowledged_by ||= recipient_name
    if order
      self.total_amount_snapshot = order.total_amount
      self.paid_amount_snapshot = order.paid_amount
      self.balance_due_snapshot = order.balance_due
      self.currency = order.currency
    end
    return if delivery_number.present? || branch.blank?

    branch.with_lock do
      self.sequence_year = handed_over_at.year
      self.sequence_number = self.class.where(branch: branch, sequence_year: sequence_year).maximum(:sequence_number).to_i + 1
      self.delivery_number = [ "DLV", branch.code, sequence_year, sequence_number.to_s.rjust(5, "0") ].join("-")
    end
  end

  def order_and_staff_belong_to_branch
    errors.add(:order, "must belong to the delivery branch") if order && branch && order.branch_id != branch_id
    if delivered_by && branch && !tenant_branch_access?(delivered_by)
      errors.add(:delivered_by, "must belong to the delivery branch")
    end
  end

  def order_is_ready
    errors.add(:order, "must be confirmed") unless order&.confirmed?
    errors.add(:order, "production must be complete before delivery") if order && !order.production_complete?
    errors.add(:order, "has already been delivered") if order&.delivery&.persisted?
  end

  def actor_can_complete_handover
    allowed = tenant_role?(delivered_by, :owner, :manager, :receptionist, :cashier)
    errors.add(:delivered_by, "is not permitted to complete a delivery") unless allowed
  end

  def outstanding_balance_requires_manager
    return unless order&.balance_due&.positive?
    return if tenant_role?(delivered_by, :owner, :manager)

    errors.add(:base, "Only an owner or manager can deliver an order with an outstanding balance")
  end

  def handover_time_is_valid
    return if handed_over_at.blank?

    errors.add(:handed_over_at, "cannot be in the future") if handed_over_at > 5.minutes.from_now
    errors.add(:handed_over_at, "cannot be before order confirmation") if order&.confirmed_at && handed_over_at < order.confirmed_at - 1.minute
  end

  def snapshots_match_order
    return unless order

    if total_amount_snapshot != order.total_amount || paid_amount_snapshot != order.paid_amount || balance_due_snapshot != order.balance_due || currency != order.currency
      errors.add(:base, "Delivery financial snapshot must match the order")
    end
  end

  def recorded_details_are_immutable
    errors.add(:base, "Recorded delivery details cannot be changed") if IMMUTABLE_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }
  end

  def acceptable_proof_images
    proof_images.each do |image|
      errors.add(:proof_images, "must be JPEG, PNG, or WebP images") unless image.blob.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(:proof_images, "must each be smaller than 8 MB") if image.blob.byte_size > 8.megabytes
    end
  end

  def prevent_destruction
    errors.add(:base, "Recorded deliveries cannot be deleted")
    throw :abort
  end
end
