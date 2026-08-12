class MeasurementProfile < ApplicationRecord
  tenant_owned_through :customer
  UNITS = %w[inches centimetres].freeze

  belongs_to :customer
  belongs_to :measurement_template
  has_many :measurements, -> { order(version: :desc) }, dependent: :restrict_with_error, inverse_of: :measurement_profile

  validates :name, :unit, presence: true
  validates :unit, inclusion: { in: UNITS }

  scope :active, -> { where(active: true) }

  delegate :branch, to: :customer

  def latest_measurement
    measurements.first
  end

  def record_measurement(attributes)
    with_lock do
      measurements.create!(attributes.merge(version: measurements.maximum(:version).to_i + 1))
    end
  end
end
