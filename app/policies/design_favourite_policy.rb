class DesignFavouritePolicy < ApplicationPolicy
  def create?
    active_tenant_user? && record.design&.shop_id == current_shop_id
  end

  def destroy?
    active_tenant_user? && record.design&.shop_id == current_shop_id && record.user_id == user.id
  end

  private

  def active_tenant_user?
    user.active? && current_membership&.active? && current_shop_id.present?
  end
end
