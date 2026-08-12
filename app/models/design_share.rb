require "digest"

class DesignShare < ApplicationRecord
  TOKEN_BYTES = 32
  DEFAULT_EXPIRY = 14.days

  attr_reader :raw_token

  belongs_to :shop
  belongs_to :created_by, class_name: "User", inverse_of: :created_design_shares
  belongs_to :customer, inverse_of: :design_shares
  belongs_to :design_collection, optional: true, inverse_of: :design_shares

  has_many :design_share_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :design_share
  has_many :designs, through: :design_share_items

  before_validation :assign_defaults, on: :create

  validates :token_digest, presence: true, uniqueness: true
  validates :token_hint, :expires_at, presence: true
  validates :allow_feedback, inclusion: { in: [ true, false ] }
  validate :relationships_belong_to_shop
  validate :creator_belongs_to_shop
  validate :expiry_is_after_creation, on: :create

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.find_active_by_token(token)
    active.find_by(token_digest: digest(token))
  end

  def active?
    revoked_at.nil? && expires_at.future?
  end

  def expired?
    expires_at <= Time.current
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def record_view!
    update_column(:viewed_at, Time.current) if viewed_at.nil?
  end

  private

  def assign_defaults
    if token_digest.blank?
      token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
      @raw_token = token
      self.token_digest = self.class.digest(token)
      self.token_hint = token.last(6)
    end
    self.expires_at ||= DEFAULT_EXPIRY.from_now
  end

  def relationships_belong_to_shop
    errors.add(:customer, "must belong to the share shop") if customer && customer.shop_id != shop_id
    if design_collection && design_collection.shop_id != shop_id
      errors.add(:design_collection, "must belong to the share shop")
    end
  end

  def creator_belongs_to_shop
    return if created_by&.memberships&.active&.exists?(shop_id: shop_id)

    errors.add(:created_by, "must belong to the share shop")
  end

  def expiry_is_after_creation
    errors.add(:expires_at, "must be in the future") unless expires_at&.future?
  end
end
