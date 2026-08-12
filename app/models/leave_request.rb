class LeaveRequest < ApplicationRecord
  tenant_owned_through :branch

  IMMUTABLE_ATTRIBUTES = %w[shop_id branch_id user_id leave_type starts_on ends_on reason].freeze

  belongs_to :branch
  belongs_to :user, inverse_of: :leave_requests
  belongs_to :reviewed_by, class_name: "User", optional: true, inverse_of: :reviewed_leave_requests

  enum :leave_type, { annual: 0, sick: 1, personal: 2, emergency: 3, unpaid: 4 }, validate: true, prefix: :leave
  enum :status, { pending: 0, approved: 1, rejected: 2, cancelled: 3 }, validate: true

  validates :starts_on, :ends_on, :reason, presence: true
  validates :reviewed_by, :reviewed_at, presence: true, if: -> { approved? || rejected? }
  validate :dates_are_valid
  validate :start_date_is_not_in_past, on: :create
  validate :people_belong_to_branch
  validate :request_details_are_immutable, on: :update
  validate :does_not_overlap_approved_leave, on: :create

  scope :recent_first, -> { order(starts_on: :desc, id: :desc) }

  def duration_days
    (ends_on - starts_on).to_i + 1
  end

  def review!(actor, decision:, notes: nil)
    raise InvalidReview, "Leave request has already been reviewed" unless pending?
    raise InvalidReview, "Decision must be approved or rejected" unless decision.to_s.in?(%w[approved rejected])
    ensure_manager!(actor)

    with_lock do
      raise InvalidReview, "Leave request has already been reviewed" unless pending?

      update!(status: decision, reviewed_by: actor, reviewed_at: Time.current, review_notes: notes)
      StaffEvent.record!(
        staff_member: user, actor: actor, event_type: "leave_#{decision}",
        details: { leave_request_id: id, starts_on: starts_on, ends_on: ends_on }
      )
    end
  end

  def cancel!(actor)
    raise InvalidReview, "Only pending leave can be cancelled" unless pending?
    raise InvalidReview, "You can only cancel your own leave" unless actor.id == user_id

    update!(status: :cancelled)
    StaffEvent.record!(staff_member: user, actor: actor, event_type: "leave_cancelled", details: { leave_request_id: id })
  end

  class InvalidReview < StandardError; end

  private

  def ensure_manager!(actor)
    raise InvalidReview, "Only an owner or manager can review leave" unless tenant_role?(actor, :owner, :manager)
    raise InvalidReview, "Manager must belong to this branch" unless tenant_branch_access?(actor)
  end

  def dates_are_valid
    errors.add(:ends_on, "must be on or after the start date") if starts_on && ends_on && ends_on < starts_on
  end

  def start_date_is_not_in_past
    errors.add(:starts_on, "cannot be in the past") if starts_on && starts_on < Date.current
  end

  def people_belong_to_branch
    errors.add(:user, "must belong to the leave branch") if user && branch && !tenant_branch_access?(user)
    errors.add(:reviewed_by, "must belong to the leave branch") if reviewed_by && branch && !tenant_branch_access?(reviewed_by)
  end

  def request_details_are_immutable
    errors.add(:base, "Submitted leave details cannot be changed") if IMMUTABLE_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }
  end

  def does_not_overlap_approved_leave
    return unless user && starts_on && ends_on

    overlap = self.class.approved.where(user: user).where("starts_on <= ? AND ends_on >= ?", ends_on, starts_on).exists?
    errors.add(:base, "Leave overlaps an approved request") if overlap
  end
end
