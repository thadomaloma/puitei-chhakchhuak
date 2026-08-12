class DesignCollectionItem < ApplicationRecord
  belongs_to :shop
  belongs_to :design_collection, counter_cache: true, inverse_of: :design_collection_items
  belongs_to :design, inverse_of: :design_collection_items
  belongs_to :added_by, class_name: "User", inverse_of: :added_design_collection_items

  before_validation :assign_shop

  validates :design_id, uniqueness: { scope: :design_collection_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :relationships_belong_to_shop
  validate :actor_belongs_to_shop

  private

  def assign_shop
    self.shop ||= design_collection&.shop
  end

  def relationships_belong_to_shop
    errors.add(:design_collection, "must belong to the item shop") if design_collection && design_collection.shop_id != shop_id
    errors.add(:design, "must belong to the item shop") if design && design.shop_id != shop_id
  end

  def actor_belongs_to_shop
    return if added_by&.memberships&.active&.exists?(shop_id: shop_id)

    errors.add(:added_by, "must belong to the item shop")
  end
end
