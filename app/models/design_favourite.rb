class DesignFavourite < ApplicationRecord
  belongs_to :shop
  belongs_to :design, inverse_of: :design_favourites
  belongs_to :user, inverse_of: :design_favourites

  before_validation :assign_shop

  validates :design_id, uniqueness: { scope: [ :shop_id, :user_id ] }
  validate :relationships_belong_to_shop

  private

  def assign_shop
    self.shop ||= design&.shop
  end

  def relationships_belong_to_shop
    errors.add(:design, "must belong to the favourite shop") if design && design.shop_id != shop_id
    return if user&.memberships&.active&.exists?(shop_id: shop_id)

    errors.add(:user, "must belong to the favourite shop")
  end
end
