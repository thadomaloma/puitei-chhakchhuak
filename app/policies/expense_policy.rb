# frozen_string_literal: true

class ExpensePolicy < ApplicationPolicy
  def index?
    financial_role?
  end

  def show?
    financial_role? && accessible_branch?
  end

  def create?
    financial_role? && accessible_branch?
  end

  def export?
    index?
  end

  def voucher?
    show?
  end

  def approve?
    show? && record.approval_pending? && !record.voided? && manager_role?
  end

  def void?
    show? && !record.voided? && manager_role?
  end

  def record_next?
    create? && record.recurring? && record.approval_approved? && !record.voided? && record.next_due_on <= Date.current
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

  def manager_role?
    user.owner? || user.manager?
  end

  def accessible_branch?
    return current_shop_id.present? if record == Expense

    accessible_tenant_branch?
  end
end
