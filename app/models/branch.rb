class Branch < ApplicationRecord
  belongs_to :shop
  has_many :memberships, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :inventory_items, dependent: :restrict_with_error
  has_many :deliveries, dependent: :restrict_with_error
  has_many :expenses, dependent: :restrict_with_error
  has_many :staff_events, dependent: :restrict_with_error
  has_many :attendance_records, dependent: :restrict_with_error
  has_many :leave_requests, dependent: :restrict_with_error
  has_many :work_shifts, dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error
  has_many :customers, dependent: :restrict_with_error
  has_one :shop_setting, dependent: :destroy

  before_validation :normalize_code
  after_create :create_default_shop_setting!

  validates :name, :code, :locale, :time_zone, presence: true
  validates :code, uniqueness: { scope: :shop_id, case_sensitive: false }, format: { with: /\A[A-Z0-9_-]+\z/ }

  scope :active, -> { where(active: true) }

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def create_default_shop_setting!
    create_shop_setting!(shop_name: name, locale: locale)
  end
end
