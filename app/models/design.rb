class Design < ApplicationRecord
  include SearchQueryNormalization

  attr_accessor :remove_image_ids, :rights_confirmed

  belongs_to :shop
  belongs_to :uploaded_by, class_name: "User", inverse_of: :uploaded_designs
  belongs_to :rights_confirmed_by, class_name: "User", inverse_of: :rights_confirmed_designs
  belongs_to :primary_image_blob, class_name: "ActiveStorage::Blob", optional: true

  has_many :design_collection_items, dependent: :restrict_with_error, inverse_of: :design
  has_many :design_collections, through: :design_collection_items
  has_many :covered_design_collections, class_name: "DesignCollection", foreign_key: :cover_design_id,
    dependent: :nullify, inverse_of: :cover_design
  has_many :design_favourites, dependent: :destroy, inverse_of: :design
  has_many :favourited_by_users, through: :design_favourites, source: :user
  has_many :design_selections, dependent: :restrict_with_error, inverse_of: :design
  has_many :selected_customers, through: :design_selections, source: :customer
  has_many :design_share_items, dependent: :restrict_with_error, inverse_of: :design
  has_many :design_shares, through: :design_share_items
  has_many :source_ai_design_requests, class_name: "AiDesignRequest", foreign_key: :source_design_id,
    dependent: :restrict_with_error, inverse_of: :source_design
  has_many :result_ai_design_requests, class_name: "AiDesignRequest", foreign_key: :result_design_id,
    dependent: :nullify, inverse_of: :result_design

  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 480, 600 ], preprocessed: true
    attachable.variant :collection_cover, resize_to_fill: [ 960, 600 ], preprocessed: true
    attachable.variant :gallery, resize_to_limit: [ 960, 1200 ]
    attachable.variant :detail, resize_to_limit: [ 1600, 2000 ]
  end

  enum :visibility, { private: 0, customer_shareable: 1, platform_library: 2 }, validate: true, prefix: true
  enum :source_type, { original: 0, customer_reference: 1, licensed_reference: 2, other: 3 }, validate: true, prefix: true

  before_validation :normalize_search_fields

  validates :title, :garment_type, presence: true
  validates :garment_type, format: { with: /\A[a-z0-9_]+\z/ }
  validates :estimated_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :estimated_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :source_url, format: { with: /\Ahttps?:\/\/[^\s]+\z/i }, allow_blank: true
  validates :rights_confirmed_at, :rights_confirmed_by, presence: true
  validate :garment_type_uses_existing_taxonomy
  validate :tenant_actors_belong_to_shop, on: :create
  validate :at_least_one_image_remains, unless: -> { source_url.present? }
  validate :acceptable_images
  validate :primary_image_is_attached

  scope :active, -> { where(active: true) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :search, lambda { |query|
    term = sanitize_sql_like(normalize_search_query(query))
    return all if term.blank?

    where(
      "designs.title ILIKE :term OR designs.description ILIKE :term OR designs.colour_family ILIKE :term " \
      "OR designs.fabric_type ILIKE :term OR designs.occasion ILIKE :term OR array_to_string(designs.tags, ' ') ILIKE :term",
      term: "%#{term}%"
    )
  }

  def tag_list
    tags.join(", ")
  end

  def tag_list=(value)
    self.tags = value.to_s.split(",")
  end

  def primary_image_attachment
    images.attachments.find { |attachment| attachment.blob_id == primary_image_blob_id } || images.attachments.first
  end

  def usage_count
    design_selections_count + design_share_items_count
  end

  def removable_image_ids
    Array(remove_image_ids).reject(&:blank?).map(&:to_s)
  end

  def instagram_reference?
    Instagram::UrlValidator.valid?(source_url)
  end

  private

  def normalize_search_fields
    self.title = title.to_s.strip
    self.garment_type = garment_type.to_s.parameterize(separator: "_")
    self.tags = Array(tags).filter_map { |tag| tag.to_s.strip.downcase.presence }.uniq.first(20)
  end

  def garment_type_uses_existing_taxonomy
    return if garment_type.blank? || MeasurementTemplate.active.exists?(garment_type: garment_type)

    errors.add(:garment_type, "must use an active measurement garment type")
  end

  def at_least_one_image_remains
    remaining = images.attachments.reject { |attachment| removable_image_ids.include?(attachment.id.to_s) }
    errors.add(:images, "must include at least one image") if remaining.empty?
  end

  def tenant_actors_belong_to_shop
    errors.add(:uploaded_by, "must belong to the design shop") unless uploaded_by&.memberships&.active&.exists?(shop_id: shop_id)
    errors.add(:rights_confirmed_by, "must belong to the design shop") unless rights_confirmed_by&.memberships&.active&.exists?(shop_id: shop_id)
  end

  def acceptable_images
    images.blobs.each do |blob|
      errors.add(:images, "must be JPEG, PNG, or WebP files") unless blob.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(:images, "must each be smaller than 8 MB") if blob.byte_size > 8.megabytes
    end
  end

  def primary_image_is_attached
    return if primary_image_blob_id.blank?
    return if images.attachments.any? { |attachment| attachment.blob_id == primary_image_blob_id }

    errors.add(:primary_image_blob, "must be one of the design images")
  end
end
