class DesignSelectionPolicy < ApplicationPolicy
  def index?
    active_tenant_user? && manager_or_front_desk?
  end

  def show?
    index? && same_shop?
  end

  def create?
    index?
  end

  def update?
    show? && !record.archived?
  end

  def destroy?
    archive?
  end

  def archive?
    update?
  end

  def restore?
    show? && record.archived?
  end

  def manage_internal_notes?
    show? && (user.owner? || user.manager?)
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
