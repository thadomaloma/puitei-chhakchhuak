class AttendanceRecord < ApplicationRecord
  tenant_owned_through :branch

  IMMUTABLE_ATTRIBUTES = %w[shop_id branch_id user_id work_date checked_in_at].freeze

  belongs_to :branch
  belongs_to :user, inverse_of: :attendance_records

  validates :work_date, :checked_in_at, presence: true
  validates :work_date, uniqueness: { scope: %i[shop_id user_id] }
  validate :user_belongs_to_branch
  validate :checkout_after_checkin
  validate :core_details_are_immutable, on: :update

  scope :recent_first, -> { order(work_date: :desc, checked_in_at: :desc) }
  scope :open, -> { where(checked_out_at: nil) }

  def checked_out?
    checked_out_at.present?
  end

  def duration_hours(reference_time = Time.current)
    finish = checked_out_at || reference_time
    ((finish - checked_in_at) / 1.hour).round(2)
  end

  def check_out!(actor, notes: nil)
    raise InvalidCheckout, "Attendance is already checked out" if checked_out?
    raise InvalidCheckout, "You can only check out yourself" unless actor.id == user_id

    with_lock do
      raise InvalidCheckout, "Attendance is already checked out" if checked_out?

      update!(checked_out_at: Time.current, notes: notes.presence || self.notes)
      StaffEvent.record!(staff_member: user, actor: actor, event_type: "checked_out", details: { attendance_id: id })
    end
  end

  class InvalidCheckout < StandardError; end

  private

  def user_belongs_to_branch
    errors.add(:user, "must belong to the attendance branch") if user && branch && !tenant_branch_access?(user)
  end

  def checkout_after_checkin
    errors.add(:checked_out_at, "must be after check-in") if checked_out_at && checked_in_at && checked_out_at <= checked_in_at
  end

  def core_details_are_immutable
    errors.add(:base, "Attendance check-in details cannot be changed") if IMMUTABLE_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }
  end
end
