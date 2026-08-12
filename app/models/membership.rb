class Membership < ApplicationRecord
  ROLES = {
    owner: 0, manager: 1, receptionist: 2, cashier: 3, tailor: 4,
    cutting_staff: 5, embroidery_staff: 6, ironing_staff: 7
  }.freeze

  belongs_to :shop
  belongs_to :user
  belongs_to :branch

  enum :role, ROLES, validate: true
  enum :pay_basis, { monthly_salary: 0, hourly: 1, daily: 2, piece_rate: 3 }, validate: true, prefix: :pay

  validates :user_id, uniqueness: { scope: :shop_id }
  validates :employee_code, uniqueness: { scope: :shop_id }, allow_blank: true
  validates :pay_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :active, inclusion: { in: [ true, false ] }
  validate :branch_belongs_to_shop

  scope :active, -> { where(active: true) }

  private

  def branch_belongs_to_shop
    errors.add(:branch, "must belong to the membership shop") if branch && shop && branch.shop_id != shop_id
  end
end
