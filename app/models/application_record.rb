class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.tenant_owned_through(source)
    belongs_to :shop
    before_validation -> { self.shop ||= public_send(source)&.shop }
    validate lambda {
      source_record = public_send(source)
      if shop && source_record&.shop_id && source_record.shop_id != shop_id
        errors.add(:shop, "must match #{source.to_s.humanize.downcase}")
      end
    }
  end

  private

  def tenant_membership_for(person)
    person&.membership_for(shop)
  end

  def tenant_role?(person, *roles)
    tenant_membership_for(person)&.role.in?(roles.map(&:to_s))
  end

  def tenant_branch_access?(person, target_branch_id = try(:branch_id))
    membership = tenant_membership_for(person)
    membership.present? && (membership.owner? || membership.branch_id == target_branch_id)
  end
end
