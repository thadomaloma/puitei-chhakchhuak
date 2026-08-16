class ShopSetting < ApplicationRecord
  tenant_owned_through :branch
  belongs_to :branch
  has_one_attached :logo

  MEASUREMENT_UNITS = %w[inches centimetres].freeze
  SUPPORTED_LOCALES = %w[en lus hi].freeze
  UPI_ID_FORMAT = /\A[a-z0-9][a-z0-9._-]*@[a-z0-9][a-z0-9._-]*\z/i
  GPAY_NUMBER_FORMAT = /\A[6-9]\d{9}\z/
  INSTAGRAM_USERNAME_FORMAT = /\A[a-z0-9._]{1,30}\z/i

  before_validation :normalize_payment_profile
  before_validation :normalize_instagram_username

  validates :shop_name, :currency, :measurement_unit, :invoice_prefix, :locale, presence: true
  validates :branch_id, uniqueness: true
  validates :measurement_unit, inclusion: { in: MEASUREMENT_UNITS }
  validates :locale, inclusion: { in: SUPPORTED_LOCALES }
  validates :tax_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :default_delivery_days, numericality: { only_integer: true, greater_than: 0 }
  validates :low_stock_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :upi_id, length: { maximum: 100 }, format: { with: UPI_ID_FORMAT }, allow_blank: true
  validates :gpay_number, format: { with: GPAY_NUMBER_FORMAT }, allow_blank: true
  validates :instagram_username, format: { with: INSTAGRAM_USERNAME_FORMAT }, allow_blank: true

  def payment_profile_configured?
    upi_id.present? || gpay_number.present?
  end

  def instagram_profile_url
    "https://www.instagram.com/#{instagram_username}/" if instagram_username.present?
  end

  private

  def normalize_payment_profile
    self.upi_id = upi_id.to_s.strip.downcase.presence

    normalized_number = gpay_number.to_s.strip.gsub(/[\s()-]/, "")
    normalized_number = normalized_number.delete_prefix("+91")
    normalized_number = normalized_number.delete_prefix("91") if normalized_number.match?(/\A91\d{10}\z/)
    self.gpay_number = normalized_number.presence
  end

  def normalize_instagram_username
    value = instagram_username.to_s.strip
    value = value.sub(%r{\Ahttps?://(www\.)?instagram\.com/}i, "").split("/").first.to_s if value.match?(%r{instagram\.com/}i)
    self.instagram_username = value.delete_prefix("@").presence
  end
end
