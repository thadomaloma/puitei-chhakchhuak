# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    user.owner? || user.manager?
  end

  def show?
    user.id == record.id || ((user.owner? || user.manager?) && accessible_branch?)
  end

  def create?
    return false unless user.owner? || user.manager?
    return true if user.owner?

    accessible_branch? && !record_role.in?(%w[owner manager])
  end

  def update?
    return false unless (user.owner? || user.manager?) && accessible_branch?
    return true if user.owner?

    record.id != user.id && !record_role.in?(%w[owner manager]) && !record.role.in?(%w[owner manager])
  end

  def archive?
    update? && record_membership&.active? && record.id != user.id
  end

  def compensation?
    user.owner? && accessible_branch?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = scope.joins(:memberships).where(memberships: { shop_id: current_shop_id })
      user.owner? ? relation : relation.where(memberships: { branch_id: current_branch_id })
    end
  end

  private

  def record_membership
    return unless record.persisted?

    @record_membership ||= record.memberships.find_by(shop_id: current_shop_id)
  end

  def record_role
    record_membership&.role || record.role
  end

  def accessible_branch?
    membership = record_membership
    record_shop_id = membership&.shop_id || record.branch&.shop_id
    record_branch_id = membership&.branch_id || record.branch_id
    record_shop_id == current_shop_id && (user.owner? || record_branch_id == current_branch_id)
  end
end
