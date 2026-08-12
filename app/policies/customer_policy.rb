# frozen_string_literal: true

class CustomerPolicy < ApplicationPolicy
  def index?
    customer_facing_role?
  end

  def show?
    customer_facing_role? && accessible_branch?
  end

  def create?
    user.owner? || user.manager? || user.receptionist?
  end

  def update?
    create? && accessible_branch?
  end

  def destroy?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      user.owner? ? relation : relation.where(branch_id: current_branch_id)
    end
  end

  private

  def customer_facing_role?
    user.owner? || user.manager? || user.receptionist? || user.cashier?
  end

  def accessible_branch?
    accessible_tenant_branch?
  end
end
