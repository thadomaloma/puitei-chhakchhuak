class DesignCollection < ApplicationRecord
  include SearchQueryNormalization

  FILTER_STATUSES = %w[active archived all].freeze
  DEFAULT_FILTER_STATUS = "active"

  belongs_to :shop
  belongs_to :created_by, class_name: "User", inverse_of: :created_design_collections
  belongs_to :cover_design, class_name: "Design", optional: true, inverse_of: :covered_design_collections

  has_many :design_collection_items, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :design_collection
  has_many :designs, through: :design_collection_items
  has_many :design_shares, dependent: :nullify, inverse_of: :design_collection

  enum :visibility, { private: 0, staff_visible: 1, customer_shareable: 2 }, validate: true, prefix: true

  before_validation :normalize_name
  before_validation :synchronize_archive_timestamp

  validates :name, presence: true,
    uniqueness: { scope: :shop_id, case_sensitive: false, conditions: -> { where(active: true) } }, if: :active?
  validates :active, inclusion: { in: [ true, false ] }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :creator_belongs_to_shop
  validate :cover_design_is_eligible

  scope :active, -> { where(active: true) }
  scope :archived, -> { where(active: false) }
  scope :ordered, -> { order(:position, :name, :id) }
  scope :search, lambda { |query|
    term = sanitize_sql_like(normalize_search_query(query))
    return all if term.blank?

    where("design_collections.name ILIKE :term OR design_collections.description ILIKE :term", term: "%#{term}%")
  }

  def archive!
    update!(active: false, archived_at: Time.current)
  end

  def restore!
    update!(active: true, archived_at: nil)
  end

  private

  def normalize_name
    self.name = name.to_s.squish
  end

  def synchronize_archive_timestamp
    return unless new_record? || will_save_change_to_active?

    self.archived_at = active? ? nil : (archived_at || Time.current)
  end

  def creator_belongs_to_shop
    return if created_by&.memberships&.active&.exists?(shop_id: shop_id)

    errors.add(:created_by, "must belong to the collection shop")
  end

  def cover_design_is_eligible
    return unless cover_design

    errors.add(:cover_design, "must belong to the collection shop") if cover_design.shop_id != shop_id
    errors.add(:cover_design, "must be active") unless cover_design.active?
    errors.add(:cover_design, "must belong to the collection") unless design_collection_items.exists?(design_id: cover_design.id)
    errors.add(:cover_design, "must have an image") unless cover_design.images.attached?
  end
end
