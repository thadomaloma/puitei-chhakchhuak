# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def index?
    financial_role?
  end

  def show?
    financial_role? && accessible_branch?
  end

  def create?
    show? && record.order.billable? && !record.order.cancelled? && record.order.balance_due.positive?
  end

  def receipt?
    show?
  end

  def void?
    show? && !record.voided? && (user.owner? || user.manager?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      user.owner? ? relation : relation.where(branch_id: current_branch_id)
    end
  end

  private

  def financial_role?
    user.owner? || user.manager? || user.receptionist? || user.cashier?
  end

  def accessible_branch?
    return current_shop_id.present? if record == Payment

    same_shop? && (user.owner? || (record.branch_id || record.order&.branch_id) == current_branch_id)
  end
end
