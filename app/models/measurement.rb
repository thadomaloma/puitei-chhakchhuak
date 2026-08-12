class Measurement < ApplicationRecord
  tenant_owned_through :measurement_profile
  belongs_to :measurement_profile, inverse_of: :measurements
  belongs_to :created_by, class_name: "User"
  belongs_to :copied_from, class_name: "Measurement", optional: true
  has_many :copies, class_name: "Measurement", foreign_key: :copied_from_id, dependent: :nullify, inverse_of: :copied_from
  has_many_attached :photos do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 640, 640 ]
  end
  has_many :order_items, dependent: :restrict_with_error

  before_validation :normalize_values

  validates :version, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :measurement_profile_id }
  validates :measured_on, presence: true
  validate :values_match_template
  validate :acceptable_photos

  delegate :customer, :measurement_template, :unit, :branch, to: :measurement_profile

  def readonly?
    persisted?
  end

  private

  def normalize_values
    self.values = values.to_h.each_with_object({}) do |(key, value), normalized|
      next if value.blank?

      normalized[key.to_s] = BigDecimal(value.to_s).to_s("F")
    rescue ArgumentError
      normalized[key.to_s] = value.to_s
    end
  end

  def values_match_template
    fields = measurement_template&.measurement_fields.to_a
    return if fields.empty? && values.blank?

    allowed_keys = fields.map(&:key)
    unknown_keys = values.keys - allowed_keys
    errors.add(:values, "contains unknown fields: #{unknown_keys.join(', ')}") if unknown_keys.any?

    fields.select(&:required?).each do |field|
      errors.add(:values, "must include #{field.label}") if values[field.key].blank?
    end

    values.each do |key, value|
      decimal = BigDecimal(value.to_s)
      errors.add(:values, "for #{key.humanize} must be greater than zero") unless decimal.positive?
      errors.add(:values, "for #{key.humanize} is too large") if decimal > 10_000
    rescue ArgumentError
      errors.add(:values, "for #{key.humanize} must be a number")
    end
  end

  def acceptable_photos
    photos.each do |photo|
      errors.add(:photos, "must be JPEG, PNG, or WebP images") unless photo.blob.content_type.in?(%w[image/jpeg image/png image/webp])
      errors.add(:photos, "must each be smaller than 8 MB") if photo.blob.byte_size > 8.megabytes
    end
  end
end
