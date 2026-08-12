class DesignPolicy < ApplicationPolicy
  def index?
    active_tenant_user?
  end

  def show?
    active_tenant_user? && same_shop?
  end

  def create?
    active_tenant_user? && (user.owner? || user.manager? || user.receptionist?)
  end

  def update?
    create? && same_shop? && !record.visibility_platform_library?
  end

  def archive?
    active_tenant_user? && same_shop? && record.active? && (user.owner? || user.manager?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      tenant_scope
    end
  end

  private

  def active_tenant_user?
    user.active? && current_membership&.active? && current_shop_id.present?
  end
end
