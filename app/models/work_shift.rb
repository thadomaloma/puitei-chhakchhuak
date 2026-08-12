class WorkShift < ApplicationRecord
  tenant_owned_through :branch

  IMMUTABLE_ATTRIBUTES = %w[shop_id branch_id user_id created_by_id starts_at ends_at location notes].freeze

  belongs_to :branch
  belongs_to :user, inverse_of: :work_shifts
  belongs_to :created_by, class_name: "User", inverse_of: :created_work_shifts
  belongs_to :cancelled_by, class_name: "User", optional: true, inverse_of: :cancelled_work_shifts

  validates :starts_at, :ends_at, presence: true
  validates :cancel_reason, :cancelled_by, presence: true, if: :cancelled?
  validate :ends_after_start
  validate :start_time_is_not_in_past, on: :create
  validate :people_belong_to_branch
  validate :schedule_details_are_immutable, on: :update
  validate :does_not_overlap_active_shift, on: :create

  scope :active, -> { where(cancelled_at: nil) }
  scope :chronological, -> { order(:starts_at, :id) }

  def cancelled?
    cancelled_at.present?
  end

  def cancel!(actor, reason:)
    raise InvalidCancellation, "Shift is already cancelled" if cancelled?
    raise InvalidCancellation, "A reason is required" if reason.blank?
    ensure_manager!(actor)

    with_lock do
      raise InvalidCancellation, "Shift is already cancelled" if cancelled?

      update!(cancelled_at: Time.current, cancelled_by: actor, cancel_reason: reason)
      StaffEvent.record!(staff_member: user, actor: actor, event_type: "shift_cancelled", details: { work_shift_id: id })
    end
  end

  class InvalidCancellation < StandardError; end

  private

  def ensure_manager!(actor)
    raise InvalidCancellation, "Only an owner or manager can cancel shifts" unless tenant_role?(actor, :owner, :manager)
    raise InvalidCancellation, "Manager must belong to this branch" unless tenant_branch_access?(actor)
  end

  def ends_after_start
    errors.add(:ends_at, "must be after the start time") if starts_at && ends_at && ends_at <= starts_at
  end

  def start_time_is_not_in_past
    errors.add(:starts_at, "cannot be in the past") if starts_at && starts_at < Time.current
  end

  def people_belong_to_branch
    { user: user, created_by: created_by, cancelled_by: cancelled_by }.each do |name, person|
      errors.add(name, "must belong to the shift branch") if person && branch && !tenant_branch_access?(person)
    end
  end

  def schedule_details_are_immutable
    errors.add(:base, "Scheduled shift details cannot be changed") if IMMUTABLE_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }
  end

  def does_not_overlap_active_shift
    return unless user && starts_at && ends_at

    overlap = self.class.active.where(shop: shop, user: user).where("starts_at < ? AND ends_at > ?", ends_at, starts_at).exists?
    errors.add(:base, "Shift overlaps another active shift") if overlap
  end
end
