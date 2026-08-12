class MeasurementTemplate < ApplicationRecord
  has_many :measurement_fields, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :measurement_template
  has_many :measurement_profiles, dependent: :restrict_with_error

  accepts_nested_attributes_for :measurement_fields, allow_destroy: true

  before_validation :normalize_garment_type

  validates :name, :garment_type, presence: true
  validates :garment_type, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  private

  def normalize_garment_type
    self.garment_type = garment_type.to_s.parameterize(separator: "_")
  end
end
