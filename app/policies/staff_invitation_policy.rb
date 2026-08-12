class StaffInvitationPolicy < ApplicationPolicy
  def index?
    user.owner? || user.manager?
  end

  def create?
    index? && record.shop_id == current_shop_id && record.branch&.shop_id == current_shop_id
  end

  def revoke?
    create? && record.usable?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      tenant_scope
    end
  end
end
