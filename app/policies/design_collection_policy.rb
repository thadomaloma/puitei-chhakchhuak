class DesignCollectionPolicy < ApplicationPolicy
  def index?
    active_tenant_user?
  end

  def show?
    active_tenant_user? && same_shop?
  end

  def create?
    active_tenant_user? && manager_or_front_desk?
  end

  def update?
    create? && same_shop? && record.active?
  end

  def manage_items?
    update?
  end

  def set_cover?
    update?
  end

  def archive?
    active_tenant_user? && same_shop? && record.active? && (user.owner? || user.manager?)
  end

  def restore?
    active_tenant_user? && same_shop? && !record.active? && (user.owner? || user.manager?)
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

  def manager_or_front_desk?
    user.owner? || user.manager? || user.receptionist?
  end
end
