class DesignSelection < ApplicationRecord
  belongs_to :shop
  belongs_to :customer, inverse_of: :design_selections
  belongs_to :design, counter_cache: true, inverse_of: :design_selections
  belongs_to :selected_by, class_name: "User", inverse_of: :design_selections
  has_many :order_items, dependent: :restrict_with_error, inverse_of: :design_selection

  enum :status, { interested: 0, shortlisted: 1, approved: 2, rejected: 3, used: 4 }, validate: true

  STATUS_TRANSITIONS = {
    "interested" => %w[shortlisted rejected],
    "shortlisted" => %w[approved rejected],
    "approved" => %w[used rejected],
    "rejected" => %w[shortlisted],
    "used" => []
  }.freeze

  before_validation :assign_tenant_defaults, on: :create
  before_validation :stamp_approval, if: :entering_approved?

  validates :selected_at, presence: true
  validates :design_id, uniqueness: { scope: [ :shop_id, :customer_id ], conditions: -> { where(archived_at: nil) } },
    unless: :archived?
  validate :relationships_belong_to_shop
  validate :actor_belongs_to_shop
  validate :valid_status_transition, on: :update

  scope :active, -> { where(archived_at: nil) }
  scope :recent_first, -> { order(selected_at: :desc, id: :desc) }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  def available_statuses
    ([ status ] + STATUS_TRANSITIONS.fetch(status, [])).uniq
  end

  private

  def assign_tenant_defaults
    self.shop ||= customer&.shop || design&.shop
    self.selected_at ||= Time.current
  end

  def entering_approved?
    approved? && (new_record? || will_save_change_to_status?)
  end

  def stamp_approval
    self.approved_at ||= Time.current
  end

  def valid_status_transition
    return unless will_save_change_to_status?

    previous_status = status_was
    return if STATUS_TRANSITIONS.fetch(previous_status, []).include?(status)

    errors.add(:status, "cannot change from #{previous_status.humanize} to #{status.humanize}")
  end

  def relationships_belong_to_shop
    errors.add(:customer, "must belong to the selection shop") if customer && customer.shop_id != shop_id
    errors.add(:design, "must belong to the selection shop") if design && design.shop_id != shop_id
  end

  def actor_belongs_to_shop
    return if selected_by&.memberships&.active&.exists?(shop_id: shop_id)

    errors.add(:selected_by, "must belong to the selection shop")
  end
end
