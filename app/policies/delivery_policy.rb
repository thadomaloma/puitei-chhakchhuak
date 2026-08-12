# frozen_string_literal: true

class DeliveryPolicy < ApplicationPolicy
  def index?
    delivery_role?
  end

  def show?
    delivery_role? && accessible_branch?
  end

  def create?
    return false unless delivery_role? && accessible_branch? && record.order&.confirmed? && record.order.production_complete?
    return true unless record.order.balance_due.positive?

    user.owner? || user.manager?
  end

  def receipt?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      user.owner? ? relation : relation.where(branch_id: current_branch_id)
    end
  end

  private

  def delivery_role?
    user.active? && (user.owner? || user.manager? || user.receptionist? || user.cashier?)
  end

  def accessible_branch?
    return current_shop_id.present? if record == Delivery

    branch_id = record.branch_id || record.order&.branch_id
    same_shop? && (user.owner? || branch_id == current_branch_id)
  end
end
