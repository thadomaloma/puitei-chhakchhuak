class StaffEvent < ApplicationRecord
  tenant_owned_through :branch
  EVENT_TYPES = %w[
    staff_created profile_updated staff_archived staff_reactivated
    checked_in checked_out leave_requested leave_approved leave_rejected leave_cancelled
    shift_scheduled shift_cancelled
  ].freeze

  belongs_to :branch
  belongs_to :staff_member, class_name: "User", inverse_of: :staff_events
  belongs_to :actor, class_name: "User", inverse_of: :recorded_staff_events

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :happened_at, presence: true
  validate :people_belong_to_branch

  scope :recent_first, -> { order(happened_at: :desc, id: :desc) }

  def self.record!(staff_member:, actor:, event_type:, details: {})
    branch = staff_member.membership_for(Current.shop)&.branch || staff_member.branch
    create!(
      branch: branch, staff_member: staff_member, actor: actor,
      event_type: event_type, details: details.compact, happened_at: Time.current
    )
  end

  def readonly?
    persisted?
  end

  private

  def people_belong_to_branch
    errors.add(:staff_member, "must belong to the event branch") if staff_member && branch && !tenant_branch_access?(staff_member)
    errors.add(:actor, "must belong to the event branch") if actor && branch && !tenant_branch_access?(actor)
  end
end
