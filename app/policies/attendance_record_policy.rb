# frozen_string_literal: true

class AttendanceRecordPolicy < ApplicationPolicy
  def index?
    user.active?
  end

  def show?
    user.id == record.user_id || ((user.owner? || user.manager?) && accessible_branch?)
  end

  def create?
    user.active? && record.user_id == user.id && accessible_branch?
  end

  def check_out?
    show? && record.user_id == user.id && !record.checked_out?
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
