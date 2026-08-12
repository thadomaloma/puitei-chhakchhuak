# frozen_string_literal: true

class WorkShiftPolicy < ApplicationPolicy
  def index?
    user.active?
  end

  def show?
    record.user_id == user.id || ((user.owner? || user.manager?) && accessible_branch?)
  end

  def create?
    (user.owner? || user.manager?) && accessible_branch?
  end

  def cancel?
    create? && !record.cancelled?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      return relation if user.owner?
      return relation.where(branch_id: current_branch_id) if user.manager?

      relation.where(user_id: user.id)
    end
  end

  private

  def accessible_branch?
    accessible_tenant_branch?
  end
end
