class ProductionTask < ApplicationRecord
  tenant_owned_through :order_item
  STAGE_ROLES = {
    "cutting" => "cutting_staff",
    "embroidery" => "embroidery_staff",
    "tailoring" => "tailor",
    "finishing" => "ironing_staff"
  }.freeze

  belongs_to :order_item
  belongs_to :assigned_to, class_name: "User", optional: true, inverse_of: :assigned_production_tasks
  belongs_to :completed_by, class_name: "User", optional: true, inverse_of: :completed_production_tasks
  has_many :production_events, -> { order(created_at: :desc) }, dependent: :restrict_with_error, inverse_of: :production_task

  enum :stage, { cutting: 0, embroidery: 1, tailoring: 2, finishing: 3 }, validate: true
  enum :status, { pending: 0, in_progress: 1, completed: 2, skipped: 3 }, validate: true

  validates :stage, uniqueness: { scope: :order_item_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :staff_belongs_to_branch
  validate :staff_role_matches_stage

  delegate :order, to: :order_item
  delegate :branch, to: :order

  scope :queue_order, -> { joins(order_item: :order).order("orders.delivery_date", :position, :id) }
  scope :for_branch, ->(branch_id) { joins(order_item: :order).where(orders: { branch_id: branch_id }) }
  scope :open, -> { where.not(status: %i[completed skipped]) }
  scope :search, lambda { |query|
    term = sanitize_sql_like(query.to_s.strip)
    return all if term.blank?

    joins(order_item: { order: :customer }).where(
      "orders.order_number ILIKE :term OR customers.full_name ILIKE :term OR customers.phone_number ILIKE :term OR order_items.garment_name ILIKE :term",
      term: "%#{term}%"
    )
  }

  def eligible_user?(candidate)
    membership = candidate&.membership_for(shop)
    candidate.present? && candidate.active? && membership.present? &&
      (membership.owner? || (membership.branch_id == branch.id && (membership.manager? || membership.role == STAGE_ROLES.fetch(stage))))
  end

  def blocked?
    tasks = order_item.production_tasks
    return tasks.any? { |task| task.position < position && !task.completed? && !task.skipped? } if tasks.loaded?

    tasks.where("position < ?", position).where.not(status: %i[completed skipped]).exists?
  end

  def actionable_by?(actor)
    return false unless eligible_user?(actor)

    tenant_role?(actor, :owner, :manager) || assigned_to_id.nil? || assigned_to_id == actor.id
  end

  def claim!(actor)
    with_lock do
      raise InvalidTransition, "Task is already assigned" if assigned_to.present?
      raise InvalidTransition, "Your role does not match this stage" unless eligible_user?(actor)

      update!(assigned_to: actor)
      record_event!(actor, "claimed")
    end
  end

  def assign!(actor, assignee)
    with_lock do
      raise InvalidTransition, "Only managers can assign production work" unless tenant_role?(actor, :owner, :manager)
      raise InvalidTransition, "Assignee is not eligible for this stage" unless eligible_user?(assignee)
      raise InvalidTransition, "Finished tasks cannot be reassigned" if completed? || skipped?

      update!(assigned_to: assignee)
      record_event!(actor, "assigned", notes: assignee.name)
    end
    notify_assignment(assignee, actor)
  end

  def start!(actor)
    with_lock do
      raise InvalidTransition, "Only pending tasks can be started" unless pending?
      raise InvalidTransition, "Complete the earlier stages first" if blocked?
      raise InvalidTransition, "You cannot start this task" unless actionable_by?(actor)

      from = status
      self.assigned_to ||= actor
      update!(status: :in_progress, started_at: Time.current)
      record_event!(actor, "started", from_status: from, to_status: status)
    end
  end

  def complete!(actor, notes: nil)
    with_lock do
      raise InvalidTransition, "Only work in progress can be completed" unless in_progress?
      raise InvalidTransition, "You cannot complete this task" unless actionable_by?(actor)

      from = status
      update!(status: :completed, completed_at: Time.current, completed_by: actor, notes: notes.presence || self.notes)
      order_item.consume_reserved_inventory!(actor) if cutting?
      record_event!(actor, "completed", from_status: from, to_status: status, notes: notes)
    end
  end

  def skip!(actor, notes: nil)
    with_lock do
      raise InvalidTransition, "Only managers can skip a stage" unless tenant_role?(actor, :owner, :manager)
      raise InvalidTransition, "Finished tasks cannot be skipped" if completed? || skipped?

      from = status
      update!(status: :skipped, completed_at: Time.current, completed_by: actor, notes: notes)
      record_event!(actor, "skipped", from_status: from, to_status: status, notes: notes)
    end
  end

  def reopen!(actor, notes: nil)
    with_lock do
      raise InvalidTransition, "Only managers can reopen a stage" unless tenant_role?(actor, :owner, :manager)
      raise InvalidTransition, "Only finished tasks can be reopened" unless completed? || skipped?
      raise InvalidTransition, "Reopen later stages first" if order_item.production_tasks.where("position > ?", position).where(status: %i[in_progress completed]).exists?

      from = status
      update!(status: :pending, started_at: nil, completed_at: nil, completed_by: nil)
      record_event!(actor, "reopened", from_status: from, to_status: status, notes: notes)
    end
  end

  class InvalidTransition < StandardError; end

  private

  def record_event!(actor, event_type, from_status: nil, to_status: nil, notes: nil)
    production_events.create!(actor: actor, event_type: event_type, from_status: from_status, to_status: to_status, notes: notes)
  end

  def notify_assignment(assignee, actor)
    Notification.notify_once!(
      recipient: assignee, actor: actor, notification_type: :work_assigned, notifiable: order,
      title: I18n.t("notifications.work_assigned.title"),
      message: I18n.t("notifications.work_assigned.message", garment: order_item.garment_name, order_number: order.order_number)
    )
  rescue StandardError => e
    Rails.logger.error("Failed to notify production task #{id} assignment: #{e.message}")
  end

  def staff_belongs_to_branch
    [ assigned_to, completed_by ].compact.each do |staff|
      errors.add(:base, "Production staff must belong to the order branch") if branch && !tenant_branch_access?(staff, branch.id)
    end
  end

  def staff_role_matches_stage
    errors.add(:assigned_to, "role does not match this production stage") if assigned_to && branch && !eligible_user?(assigned_to)
  end
end
