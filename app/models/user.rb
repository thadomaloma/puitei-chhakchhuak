class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable, :timeoutable, :lockable

  belongs_to :branch, optional: true
  has_many :memberships, dependent: :restrict_with_error
  has_many :shops, through: :memberships
  has_many :created_orders, class_name: "Order", foreign_key: :created_by_id, dependent: :restrict_with_error, inverse_of: :created_by
  has_many :assigned_production_tasks, class_name: "ProductionTask", foreign_key: :assigned_to_id, dependent: :nullify, inverse_of: :assigned_to
  has_many :completed_production_tasks, class_name: "ProductionTask", foreign_key: :completed_by_id, dependent: :nullify, inverse_of: :completed_by
  has_many :production_events, foreign_key: :actor_id, dependent: :restrict_with_error, inverse_of: :actor
  has_many :received_payments, class_name: "Payment", foreign_key: :received_by_id, dependent: :restrict_with_error, inverse_of: :received_by
  has_many :voided_payments, class_name: "Payment", foreign_key: :voided_by_id, dependent: :nullify, inverse_of: :voided_by
  has_many :stock_movements, foreign_key: :actor_id, dependent: :restrict_with_error, inverse_of: :actor
  has_many :deliveries, foreign_key: :delivered_by_id, dependent: :restrict_with_error, inverse_of: :delivered_by
  has_many :recorded_expenses, class_name: "Expense", foreign_key: :recorded_by_id, dependent: :restrict_with_error, inverse_of: :recorded_by
  has_many :approved_expenses, class_name: "Expense", foreign_key: :approved_by_id, dependent: :restrict_with_error, inverse_of: :approved_by
  has_many :voided_expenses, class_name: "Expense", foreign_key: :voided_by_id, dependent: :restrict_with_error, inverse_of: :voided_by
  has_many :staff_events, foreign_key: :staff_member_id, dependent: :restrict_with_error, inverse_of: :staff_member
  has_many :recorded_staff_events, class_name: "StaffEvent", foreign_key: :actor_id, dependent: :restrict_with_error, inverse_of: :actor
  has_many :attendance_records, dependent: :restrict_with_error
  has_many :leave_requests, dependent: :restrict_with_error
  has_many :reviewed_leave_requests, class_name: "LeaveRequest", foreign_key: :reviewed_by_id, dependent: :restrict_with_error, inverse_of: :reviewed_by
  has_many :work_shifts, dependent: :restrict_with_error
  has_many :created_work_shifts, class_name: "WorkShift", foreign_key: :created_by_id, dependent: :restrict_with_error, inverse_of: :created_by
  has_many :cancelled_work_shifts, class_name: "WorkShift", foreign_key: :cancelled_by_id, dependent: :restrict_with_error, inverse_of: :cancelled_by
  has_many :uploaded_designs, class_name: "Design", foreign_key: :uploaded_by_id, dependent: :restrict_with_error, inverse_of: :uploaded_by
  has_many :rights_confirmed_designs, class_name: "Design", foreign_key: :rights_confirmed_by_id, dependent: :restrict_with_error, inverse_of: :rights_confirmed_by
  has_many :created_design_collections, class_name: "DesignCollection", foreign_key: :created_by_id, dependent: :restrict_with_error, inverse_of: :created_by
  has_many :added_design_collection_items, class_name: "DesignCollectionItem", foreign_key: :added_by_id, dependent: :restrict_with_error, inverse_of: :added_by
  has_many :design_favourites, dependent: :destroy, inverse_of: :user
  has_many :design_selections, foreign_key: :selected_by_id, dependent: :restrict_with_error, inverse_of: :selected_by
  has_many :created_design_shares, class_name: "DesignShare", foreign_key: :created_by_id,
    dependent: :restrict_with_error, inverse_of: :created_by
  has_many :ai_design_requests, foreign_key: :requested_by_id, dependent: :restrict_with_error, inverse_of: :requested_by
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient

  enum :role, {
    owner: 0,
    manager: 1,
    receptionist: 2,
    cashier: 3,
    tailor: 4,
    cutting_staff: 5,
    embroidery_staff: 6,
    ironing_staff: 7
  }, validate: true
  enum :pay_basis, { monthly_salary: 0, hourly: 1, daily: 2, piece_rate: 3 }, validate: true, prefix: :pay
  before_validation :assign_workforce_defaults, on: :create

  validates :name, presence: true
  validates :branch, :employee_code, :joined_on, presence: true
  validates :employee_code, format: { with: /\ASTF-[A-Z0-9_-]+-[0-9]{4,}\z/ }, allow_blank: true
  validates :pay_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :search, lambda { |query|
    term = sanitize_sql_like(query.to_s.strip)
    return all if term.blank?

    where(
      "users.employee_code ILIKE :term OR users.name ILIKE :term OR users.email ILIKE :term OR users.phone_number ILIKE :term OR users.job_title ILIKE :term",
      term: "%#{term}%"
    )
  }

  def active_for_authentication?
    super && active? && memberships.active.joins(:shop, :branch)
      .merge(Shop.where(active: true)).merge(Branch.active).exists?
  end

  def inactive_message
    active_for_authentication? ? super : :inactive
  end

  def membership_for(shop = Current.shop)
    return Current.membership if Current.membership&.user_id == id && Current.membership.shop_id == shop&.id
    return if shop.blank?

    memberships.active.find_by(shop: shop)
  end

  def primary_membership
    memberships.active.find_by(shop: Shop.current)
  end

  def role_for(shop = Current.shop)
    membership_for(shop)&.role || role
  end

  Membership::ROLES.each_key do |membership_role|
    define_method("#{membership_role}?") { role_for == membership_role.to_s }
  end

  def attendance_for(date = Date.current, shop = Current.shop)
    attendance_records.find_by(work_date: date, shop: shop)
  end

  private

  def assign_workforce_defaults
    self.joined_on ||= Date.current
    return if employee_code.present? || branch.blank?

    branch.with_lock do
      last_number = self.class.where(branch: branch).where.not(employee_code: nil).pluck(:employee_code)
        .filter_map { |code| code[/-(\d+)\z/, 1]&.to_i }.max.to_i
      self.employee_code = [ "STF", branch.code, (last_number + 1).to_s.rjust(4, "0") ].join("-")
    end
  end
end
