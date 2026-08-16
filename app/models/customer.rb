class Customer < ApplicationRecord
  tenant_owned_through :branch
  SUPPORTED_LANGUAGES = %w[en lus hi].freeze

  belongs_to :branch
  has_many :measurement_profiles, dependent: :restrict_with_error
  has_many :measurements, through: :measurement_profiles
  has_many :orders, dependent: :restrict_with_error
  has_many :design_selections, dependent: :restrict_with_error, inverse_of: :customer
  has_many :selected_designs, through: :design_selections, source: :design
  has_many :design_shares, dependent: :restrict_with_error, inverse_of: :customer
  has_one_attached :profile_photo do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 192, 192 ]
  end

  enum :gender, { unspecified: 0, female: 1, male: 2, non_binary: 3 }, validate: true

  before_validation :normalize_contact_details
  before_validation :assign_customer_code, on: :create

  validates :customer_code, :full_name, :phone_number, :preferred_language, presence: true
  validates :customer_code, uniqueness: { scope: :shop_id }
  validates :phone_number, uniqueness: { scope: :branch_id }, format: { with: /\A\d{7,15}\z/ }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :preferred_language, inclusion: { in: SUPPORTED_LANGUAGES }
  validates :active, inclusion: { in: [ true, false ] }
  validate :acceptable_profile_photo

  scope :active, -> { where(active: true) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :search, lambda { |query|
    term = sanitize_sql_like(query.to_s.strip)
    return all if term.blank?

    where(
      "customers.full_name ILIKE :term OR customers.phone_number ILIKE :term OR customers.whatsapp_number ILIKE :term OR customers.customer_code ILIKE :term",
      term: "%#{term}%"
    )
  }

  def archive!
    update!(active: false)
  end

  def initials
    full_name.split.filter_map { |part| part[0] }.first(2).join.upcase
  end

  # Most customers only ever give the shop one number. WhatsApp is only a
  # distinct field for the minority who use a different number for it.
  def whatsapp_contact_number
    whatsapp_number.presence || phone_number
  end

  private

  def normalize_contact_details
    self.full_name = full_name.to_s.squish
    self.phone_number = phone_number.to_s.gsub(/\D/, "")
    self.whatsapp_number = whatsapp_number.to_s.gsub(/\D/, "").presence
    self.email = email.to_s.strip.downcase.presence
  end

  def assign_customer_code
    self.customer_code ||= loop do
      candidate = "CUS-#{SecureRandom.alphanumeric(8).upcase}"
      break candidate unless self.class.exists?(customer_code: candidate)
    end
  end

  def acceptable_profile_photo
    return unless profile_photo.attached?

    errors.add(:profile_photo, "must be a JPEG, PNG, or WebP image") unless profile_photo.blob.content_type.in?(%w[image/jpeg image/png image/webp])
    errors.add(:profile_photo, "must be smaller than 5 MB") if profile_photo.blob.byte_size > 5.megabytes
  end
end
