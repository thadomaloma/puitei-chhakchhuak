class ShopPolicy < ApplicationPolicy
  def show?
    current_shop_id == record.id
  end

  def update?
    show? && (user.owner? || user.manager?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(id: current_shop_id)
    end
  end
end
