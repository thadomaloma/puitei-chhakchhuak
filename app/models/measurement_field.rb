class MeasurementField < ApplicationRecord
  belongs_to :measurement_template, inverse_of: :measurement_fields

  before_validation :normalize_key

  validates :key, :label, presence: true
  validates :key, uniqueness: { scope: :measurement_template_id }, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  private

  def normalize_key
    self.key = key.to_s.parameterize(separator: "_")
  end
end
