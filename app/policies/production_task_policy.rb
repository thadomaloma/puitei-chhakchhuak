# frozen_string_literal: true

class ProductionTaskPolicy < ApplicationPolicy
  def show?
    user.active? && accessible_branch?
  end

  def claim?
    show? && record.pending? && record.assigned_to.nil? && record.eligible_user?(user)
  end

  def start?
    show? && record.pending? && record.actionable_by?(user)
  end

  def complete?
    show? && record.in_progress? && record.actionable_by?(user)
  end

  def assign?
    manager?
  end

  def skip?
    manager? && !record.completed? && !record.skipped?
  end

  def reopen?
    manager? && (record.completed? || record.skipped?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      user.owner? ? relation : relation.joins(order_item: :order).where(orders: { branch_id: current_branch_id })
    end
  end

  private

  def manager?
    show? && (user.owner? || user.manager?)
  end

  def accessible_branch?
    same_shop? && (user.owner? || record.branch.id == current_branch_id)
  end
end
