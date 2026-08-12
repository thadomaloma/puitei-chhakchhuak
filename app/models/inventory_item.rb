class InventoryItem < ApplicationRecord
  tenant_owned_through :branch
  attr_accessor :remove_image

  belongs_to :branch
  has_many :stock_movements, -> { order(created_at: :desc, id: :desc) }, dependent: :restrict_with_error, inverse_of: :inventory_item
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 640, 640 ]
  end

  enum :category, {
    fabric: 0, thread: 1, button: 2, zipper: 3, lining: 4, trim: 5, accessory: 6, other: 7
  }, validate: true
  enum :unit, {
    metre: 0, yard: 1, piece: 2, spool: 3, roll: 4, kilogram: 5, packet: 6
  }, validate: true

  before_validation :normalize_sku

  validates :name, :sku, presence: true
  validates :sku, uniqueness: { scope: :branch_id }, format: { with: /\A[A-Z0-9_-]+\z/ }
  validates :cost_price, :selling_price, :quantity_on_hand, :quantity_reserved, :reorder_level,
    numericality: { greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
  validate :reserved_stock_is_available
  validate :stock_balances_are_ledger_controlled, on: :update
  validate :acceptable_image

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name, :id) }
  scope :low_stock, -> { active.where("quantity_on_hand - quantity_reserved <= reorder_level") }
  scope :search, lambda { |query|
    term = sanitize_sql_like(query.to_s.strip)
    return all if term.blank?

    where("inventory_items.name ILIKE :term OR inventory_items.sku ILIKE :term OR inventory_items.color ILIKE :term OR inventory_items.supplier_name ILIKE :term", term: "%#{term}%")
  }

  def available_quantity
    quantity_on_hand - quantity_reserved
  end

  def stock_status
    return "out_of_stock" if available_quantity.zero?
    return "low_stock" if available_quantity <= reorder_level

    "in_stock"
  end

  def reserved_for(order_item)
    totals = stock_movements.reorder(nil).where(order_item: order_item).group(:movement_type).sum(:quantity)
    movement_total = ->(type) { totals.fetch(type, totals.fetch(StockMovement.movement_types.fetch(type), 0.to_d)) }
    movement_total.call("reservation") - movement_total.call("release") - movement_total.call("consumption")
  end

  def record_movement!(movement_type:, quantity:, actor:, order_item: nil, happened_on: Date.current, reference: nil, notes: nil)
    type = movement_type.to_s
    raise InvalidMovement, "Unknown stock movement" unless StockMovement.movement_types.key?(type)

    amount = BigDecimal(quantity.to_s)
    raise InvalidMovement, "Quantity must be greater than zero" unless amount.positive?

    with_lock do
      validate_order_link!(type, amount, order_item)
      on_hand_delta, reserved_delta = movement_deltas(type, amount)
      new_on_hand = quantity_on_hand + on_hand_delta
      new_reserved = quantity_reserved + reserved_delta
      raise InvalidMovement, "Not enough available stock" if new_on_hand.negative? || new_reserved.negative? || new_reserved > new_on_hand

      movement = stock_movements.create!(
        actor: actor, order_item: order_item, movement_type: type, quantity: amount,
        on_hand_before: quantity_on_hand, on_hand_after: new_on_hand,
        reserved_before: quantity_reserved, reserved_after: new_reserved,
        happened_on: happened_on.presence || Date.current, reference: reference, notes: notes,
        recorded_through_inventory_item: true
      )
      update_columns(quantity_on_hand: new_on_hand, quantity_reserved: new_reserved, updated_at: Time.current)
      movement
    end
  rescue ArgumentError
    raise InvalidMovement, "Quantity must be a valid number"
  end

  class InvalidMovement < StandardError; end

  private

  def normalize_sku
    self.sku = sku.to_s.strip.upcase
  end

  def movement_deltas(type, amount)
    case type
    when "stock_in", "adjustment_in" then [ amount, 0.to_d ]
    when "stock_out", "adjustment_out", "wastage" then [ -amount, 0.to_d ]
    when "reservation" then [ 0.to_d, amount ]
    when "release" then [ 0.to_d, -amount ]
    when "consumption" then [ -amount, -amount ]
    end
  end

  def validate_order_link!(type, amount, order_item)
    linked_types = %w[reservation release consumption]
    raise InvalidMovement, "Choose an order garment for this movement" if type.in?(linked_types) && order_item.blank?
    return if order_item.blank?

    raise InvalidMovement, "Order garment must belong to the inventory branch" if order_item.branch.id != branch_id
    raise InvalidMovement, "Stock can only be allocated to a confirmed order" unless order_item.order.confirmed?

    if type.in?(%w[release consumption]) && amount > reserved_for(order_item)
      raise InvalidMovement, "Quantity exceeds the stock reserved for this garment"
    end
  end

  def reserved_stock_is_available
    return if quantity_reserved.blank? || quantity_on_hand.blank?

    errors.add(:quantity_reserved, "cannot exceed stock on hand") if quantity_reserved > quantity_on_hand
  end

  def stock_balances_are_ledger_controlled
    if will_save_change_to_quantity_on_hand? || will_save_change_to_quantity_reserved?
      errors.add(:base, "Stock balances can only change through a stock movement")
    end
  end

  def acceptable_image
    return unless image.attached?

    errors.add(:image, "must be a JPEG, PNG, or WebP image") unless image.blob.content_type.in?(%w[image/jpeg image/png image/webp])
    errors.add(:image, "must be smaller than 8 MB") if image.blob.byte_size > 8.megabytes
  end
end
