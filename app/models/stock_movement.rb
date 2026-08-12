class StockMovement < ApplicationRecord
  tenant_owned_through :inventory_item
  attr_accessor :recorded_through_inventory_item
  IMMUTABLE_ATTRIBUTES = %w[
    inventory_item_id actor_id order_item_id movement_type quantity on_hand_before on_hand_after
    reserved_before reserved_after happened_on reference notes
  ].freeze

  belongs_to :inventory_item, inverse_of: :stock_movements
  belongs_to :actor, class_name: "User", inverse_of: :stock_movements
  belongs_to :order_item, optional: true, inverse_of: :stock_movements

  enum :movement_type, {
    stock_in: 0, stock_out: 1, adjustment_in: 2, adjustment_out: 3,
    wastage: 4, reservation: 5, release: 6, consumption: 7
  }, validate: true

  validates :quantity, numericality: { greater_than: 0 }
  validates :happened_on, presence: true
  validates :on_hand_before, :on_hand_after, :reserved_before, :reserved_after,
    numericality: { greater_than_or_equal_to: 0 }
  validate :actor_and_order_belong_to_branch
  validate :order_link_is_present_when_required
  validate :balances_are_valid
  validate :recorded_details_are_immutable, on: :update
  validate :date_is_not_in_future
  validate :created_through_inventory_ledger, on: :create
  validate :balance_changes_match_movement
  before_destroy :prevent_destruction

  scope :recent_first, -> { order(happened_on: :desc, created_at: :desc, id: :desc) }

  delegate :branch, to: :inventory_item

  def reservation_delta
    return quantity if reservation?
    return -quantity if release? || consumption?

    0.to_d
  end

  private

  def actor_and_order_belong_to_branch
    if actor && inventory_item && !tenant_branch_access?(actor, inventory_item.branch_id)
      errors.add(:actor, "must belong to the inventory branch")
    end
    if order_item && inventory_item && order_item.branch.id != inventory_item.branch_id
      errors.add(:order_item, "must belong to the inventory branch")
    end
  end

  def order_link_is_present_when_required
    errors.add(:order_item, "is required") if movement_type.in?(%w[reservation release consumption]) && order_item.blank?
  end

  def balances_are_valid
    values = [ on_hand_before, on_hand_after, reserved_before, reserved_after ]
    return if values.any?(&:blank?)

    errors.add(:base, "Reserved stock cannot exceed stock on hand") if reserved_before > on_hand_before || reserved_after > on_hand_after
  end

  def recorded_details_are_immutable
    errors.add(:base, "Recorded stock movements cannot be changed") if IMMUTABLE_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }
  end

  def date_is_not_in_future
    errors.add(:happened_on, "cannot be in the future") if happened_on && happened_on > Date.current
  end

  def created_through_inventory_ledger
    errors.add(:base, "Stock movements must be recorded through the inventory ledger") unless recorded_through_inventory_item
  end

  def balance_changes_match_movement
    return if movement_type.blank? || quantity.blank? || [ on_hand_before, on_hand_after, reserved_before, reserved_after ].any?(&:blank?)

    expected_on_hand, expected_reserved = case movement_type
    when "stock_in", "adjustment_in" then [ quantity, 0.to_d ]
    when "stock_out", "adjustment_out", "wastage" then [ -quantity, 0.to_d ]
    when "reservation" then [ 0.to_d, quantity ]
    when "release" then [ 0.to_d, -quantity ]
    when "consumption" then [ -quantity, -quantity ]
    end
    if on_hand_after - on_hand_before != expected_on_hand || reserved_after - reserved_before != expected_reserved
      errors.add(:base, "Stock movement balances do not match its type and quantity")
    end
  end

  def prevent_destruction
    errors.add(:base, "Recorded stock movements cannot be deleted")
    throw :abort
  end
end
