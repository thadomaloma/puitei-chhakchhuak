require "digest"

class StaffInvitation < ApplicationRecord
  TOKEN_BYTES = 32

  belongs_to :shop
  belongs_to :branch
  belongs_to :invited_by, class_name: "User"

  enum :role, Membership::ROLES.except(:owner), validate: true

  attr_reader :raw_token

  before_validation :normalize_email
  before_validation :assign_token, on: :create
  before_validation :assign_expiry, on: :create

  validates :email, :token_digest, :expires_at, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :branch_and_inviter_belong_to_shop
  validate :no_duplicate_pending_invitation, on: :create

  scope :active, -> { where(accepted_at: nil, revoked_at: nil).where(expires_at: Time.current..) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def self.find_by_token(token)
    find_by(token_digest: digest(token)) if token.present?
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def usable?
    accepted_at.nil? && revoked_at.nil? && expires_at.future?
  end

  def accept!(user)
    raise InvalidInvitation, "Invitation is no longer valid" unless usable?
    raise InvalidInvitation, "Invitation email does not match this account" unless user.email.casecmp?(email)

    transaction do
      membership = shop.memberships.create!(
        user: user, branch: branch, role: role, active: true, employee_code: next_employee_code,
        joined_on: user.joined_on, pay_basis: user.pay_basis, pay_rate: user.pay_rate, accepted_at: Time.current
      )
      update!(accepted_at: Time.current)
      BusinessAuditEvent.record!(action: "staff_invitation.accepted", shop: shop, actor: user, auditable: self)
      membership
    end
  rescue ActiveRecord::RecordNotUnique
    raise InvalidInvitation, "This account already belongs to the shop"
  end

  def revoke!(actor)
    raise InvalidInvitation, "Invitation is no longer active" unless usable?

    update!(revoked_at: Time.current)
    BusinessAuditEvent.record!(action: "staff_invitation.revoked", shop: shop, actor: actor, auditable: self)
  end

  class InvalidInvitation < StandardError; end

  private

  def assign_token
    @raw_token = SecureRandom.hex(TOKEN_BYTES)
    self.token_digest = self.class.digest(@raw_token)
  end

  def assign_expiry
    self.expires_at ||= 7.days.from_now
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def branch_and_inviter_belong_to_shop
    errors.add(:branch, "must belong to the invitation shop") if branch && shop && branch.shop_id != shop_id
    return unless invited_by && shop

    inviter_membership = invited_by.memberships.active.find_by(shop: shop)
    errors.add(:invited_by, "must manage the invitation shop") unless inviter_membership&.role.in?(%w[owner manager])
  end

  def no_duplicate_pending_invitation
    return if email.blank? || shop.blank?

    if shop.staff_invitations.where(accepted_at: nil, revoked_at: nil).where("LOWER(email) = ?", email.downcase).exists?
      errors.add(:email, "already has a pending invitation")
    end
  end

  def next_employee_code
    branch.with_lock do
      last_number = shop.memberships.where.not(employee_code: nil).pluck(:employee_code)
        .filter_map { |code| code[/-(\d+)\z/, 1]&.to_i }.max.to_i
      [ "STF", branch.code, (last_number + 1).to_s.rjust(4, "0") ].join("-")
    end
  end
end
