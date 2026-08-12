# frozen_string_literal: true

class InventoryItemPolicy < ApplicationPolicy
  def index?
    user.active?
  end

  def show?
    user.active? && accessible_branch?
  end

  def create?
    user.active? && (user.owner? || user.manager?)
  end

  def update?
    create? && accessible_branch?
  end

  def archive?
    update? && record.active? && record.quantity_reserved.zero?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      user.owner? ? relation : relation.where(branch_id: current_branch_id)
    end
  end

  private

  def accessible_branch?
    return current_shop_id.present? if record == InventoryItem

    accessible_tenant_branch?
  end
end
