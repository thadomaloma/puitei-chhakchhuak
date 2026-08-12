class Shop < ApplicationRecord
  # The one Puitei Chhakchhuak business profile. Historical multi-shop demo/test
  # data may still exist in the database (see docs/product_architecture_realign.md);
  # this is the only shop the running application ever operates against.
  CANONICAL_SLUG = "puitei-studio"

  belongs_to :created_by, class_name: "User", optional: true
  has_many :branches, dependent: :restrict_with_error
  has_many :memberships, dependent: :restrict_with_error
  has_many :users, through: :memberships
  has_one :owner_membership, -> { where(active: true, role: Membership::ROLES.fetch(:owner)).order(:id) },
    class_name: "Membership"
  has_one :owner, through: :owner_membership, source: :user
  has_many :staff_invitations, dependent: :restrict_with_error
  has_many :business_audit_events, dependent: :nullify
  has_many :customers, dependent: :restrict_with_error
  has_many :measurement_profiles, dependent: :restrict_with_error
  has_many :measurements, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error
  has_many :order_items, dependent: :restrict_with_error
  has_many :production_tasks, dependent: :restrict_with_error
  has_many :production_events, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :deliveries, dependent: :restrict_with_error
  has_many :inventory_items, dependent: :restrict_with_error
  has_many :stock_movements, dependent: :restrict_with_error
  has_many :expenses, dependent: :restrict_with_error
  has_many :designs, dependent: :restrict_with_error
  has_many :design_collections, dependent: :restrict_with_error
  has_many :design_collection_items, dependent: :restrict_with_error
  has_many :design_favourites, dependent: :restrict_with_error
  has_many :design_selections, dependent: :restrict_with_error
  has_many :design_shares, dependent: :restrict_with_error
  has_many :design_share_items, dependent: :restrict_with_error
  has_many :ai_design_requests, dependent: :restrict_with_error
  has_one_attached :logo

  before_validation :normalize_slug

  validates :name, :slug, :country, presence: true
  validates :slug, uniqueness: { case_sensitive: false }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }

  def self.current
    find_by!(slug: CANONICAL_SLUG, active: true)
  end

  def default_branch
    branches.active.order(:id).first || branches.order(:id).first
  end

  def onboarding_complete?
    onboarding_completed_at.present?
  end

  private

  def normalize_slug
    self.slug = (slug.presence || name).to_s.parameterize
  end
end
