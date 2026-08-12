class OrderItem < ApplicationRecord
  tenant_owned_through :order
  belongs_to :order, inverse_of: :order_items
  belongs_to :measurement
  belongs_to :design_selection, optional: true, inverse_of: :order_items
  has_many_attached :fabric_photos do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 640, 640 ]
  end
  has_many_attached :design_references do |attachable|
    attachable.variant :thumb, resize_to_limit: [ 640, 640 ]
  end
  has_many :production_tasks, -> { order(:position) }, dependent: :restrict_with_error, inverse_of: :order_item
  has_many :stock_movements, dependent: :restrict_with_error, inverse_of: :order_item

  before_validation :capture_measurement_snapshot, on: :create
  after_create :mark_design_selection_used

  validates :garment_name, presence: true
  validates :quantity, numericality: { only_integer: true, in: 1..100 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validate :measurement_belongs_to_customer
  validate :measurement_snapshot_is_complete
  validate :design_selection_belongs_to_customer
  validate :snapshot_is_immutable, on: :update
  validate :price_is_immutable_after_confirmation, on: :update
  validate :acceptable_images

  delegate :customer, :branch, to: :order

  def create_production_tasks!
    stages = %w[cutting]
    stages << "embroidery" if requires_embroidery?
    stages.concat(%w[tailoring finishing])
    stages.each_with_index do |stage, position|
      production_tasks.find_or_create_by!(stage: stage) { |task| task.position = position }
    end
  end

  def production_complete?
    production_tasks.any? && production_tasks.where.not(status: %i[completed skipped]).none?
  end

  def line_total
    quantity * unit_price
  end

  def active_inventory_reservations
    stock_movements.includes(:inventory_item).group_by(&:inventory_item).filter_map do |item, movements|
      quantity = movements.sum(&:reservation_delta)
      [ item, quantity ] if quantity.positive?
    end.to_h
  end

  def consumed_inventory
    stock_movements.includes(:inventory_item).select(&:consumption?).group_by(&:inventory_item).transform_values { |movements| movements.sum(&:quantity) }
  end

  def consume_reserved_inventory!(actor)
    active_inventory_reservations.sort_by { |item, _quantity| item.id }.each do |item, quantity|
      item.record_movement!(movement_type: :consumption, quantity: quantity, actor: actor, order_item: self, notes: "Consumed when cutting was completed")
    end
  end

  def readonly_snapshot
    measurement_snapshot.deep_symbolize_keys
  end

  private

  def capture_measurement_snapshot
    return if measurement.blank? || measurement_snapshot.present?

    profile = measurement.measurement_profile
    self.measurement_snapshot = {
      "measurement_id" => measurement.id,
      "profile_id" => profile.id,
      "profile_name" => profile.name,
      "template_name" => profile.measurement_template.name,
      "garment_type" => profile.measurement_template.garment_type,
      "version" => measurement.version,
      "measured_on" => measurement.measured_on.iso8601,
      "unit" => profile.unit,
      "values" => measurement.values.deep_dup,
      "fields" => profile.measurement_template.measurement_fields.map { |field| { "key" => field.key, "label" => field.label } },
      "measurement_notes" => measurement.notes,
      "fitting_notes" => profile.fitting_notes,
      "posture_notes" => profile.posture_notes,
      "preferences" => profile.preferences
    }
  end

  def measurement_belongs_to_customer
    return if measurement.blank? || order.blank?

    errors.add(:measurement, "must belong to the order customer") if measurement.customer.id != order.customer_id
  end

  def measurement_snapshot_is_complete
    required = %w[measurement_id profile_name template_name version measured_on unit values fields]
    errors.add(:measurement_snapshot, "is incomplete") unless required.all? { |key| measurement_snapshot[key].present? || measurement_snapshot[key] == 0 }
  end

  def snapshot_is_immutable
    errors.add(:measurement_snapshot, "cannot be changed after the order item is created") if will_save_change_to_measurement_snapshot?
    errors.add(:measurement, "cannot be changed after the order item is created") if will_save_change_to_measurement_id?
    errors.add(:design_selection, "cannot be changed after the order item is created") if will_save_change_to_design_selection_id?
  end

  def design_selection_belongs_to_customer
    return if design_selection.blank? || order.blank?

    errors.add(:design_selection, "must belong to the order customer") if design_selection.customer_id != order.customer_id
  end

  def mark_design_selection_used
    design_selection&.update!(status: :used) if design_selection&.approved?
  end

  def price_is_immutable_after_confirmation
    return unless order&.billable?

    errors.add(:base, "Confirmed garment quantity and price cannot be changed") if will_save_change_to_quantity? || will_save_change_to_unit_price?
  end

  def acceptable_images
    [ fabric_photos, design_references ].each do |attachments|
      attachments.each do |image|
        errors.add(attachments.name, "must be JPEG, PNG, or WebP images") unless image.blob.content_type.in?(%w[image/jpeg image/png image/webp])
        errors.add(attachments.name, "must each be smaller than 8 MB") if image.blob.byte_size > 8.megabytes
      end
    end
  end
end
