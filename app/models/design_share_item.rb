class DesignShareItem < ApplicationRecord
  belongs_to :shop
  belongs_to :design_share, inverse_of: :design_share_items
  belongs_to :design, counter_cache: true, inverse_of: :design_share_items

  enum :customer_reaction,
    { no_response: 0, liked: 1, not_interested: 2, shortlisted: 3 }, validate: true, prefix: true

  before_validation :assign_shop
  before_validation :set_response_time, if: :feedback_changed?

  validates :design_id, uniqueness: { scope: :design_share_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :customer_comment, length: { maximum: 1_000 }
  validate :relationships_belong_to_shop
  validate :design_is_shareable, on: :create

  private

  def assign_shop
    self.shop ||= design_share&.shop
  end

  def feedback_changed?
    will_save_change_to_customer_reaction? || will_save_change_to_customer_comment?
  end

  def set_response_time
    self.responded_at = Time.current unless customer_reaction_no_response? && customer_comment.blank?
  end

  def relationships_belong_to_shop
    errors.add(:design_share, "must belong to the item shop") if design_share && design_share.shop_id != shop_id
    errors.add(:design, "must belong to the item shop") if design && design.shop_id != shop_id
  end

  def design_is_shareable
    return unless design

    errors.add(:design, "must be active") unless design.active?
    errors.add(:design, "must be customer shareable") unless design.visibility_customer_shareable?
  end
end
