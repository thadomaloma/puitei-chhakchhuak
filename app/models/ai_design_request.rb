class AiDesignRequest < ApplicationRecord
  belongs_to :shop
  belongs_to :requested_by, class_name: "User", inverse_of: :ai_design_requests
  belongs_to :source_design, class_name: "Design", optional: true, inverse_of: :source_ai_design_requests
  belongs_to :result_design, class_name: "Design", optional: true, inverse_of: :result_ai_design_requests

  enum :request_type, {
    text_to_design: 0, colour_variation: 1, neck_variation: 2,
    sleeve_variation: 3, embroidery_variation: 4, edit_existing: 5
  }, validate: true, prefix: true
  enum :status, {
    pending: 0, processing: 1, completed: 2, failed: 3, cancelled: 4, rejected: 5
  }, validate: true, prefix: true

  validates :prompt, :provider, presence: true
  validates :credit_cost, numericality: { only_integer: true, greater_than: 0 }
  validates :metadata, presence: true
  validate :relationships_belong_to_shop
  validate :requester_belongs_to_shop

  scope :chargeable, -> { where(status: %i[pending processing completed]) }

  private

  def relationships_belong_to_shop
    errors.add(:source_design, "must belong to the request shop") if source_design && source_design.shop_id != shop_id
    errors.add(:result_design, "must belong to the request shop") if result_design && result_design.shop_id != shop_id
  end

  def requester_belongs_to_shop
    return if requested_by&.memberships&.active&.exists?(shop_id: shop_id)

    errors.add(:requested_by, "must belong to the request shop")
  end
end
