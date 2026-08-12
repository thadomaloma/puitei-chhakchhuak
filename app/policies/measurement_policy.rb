# frozen_string_literal: true

class MeasurementPolicy < ApplicationPolicy
  def show?
    permitted_role? && accessible_branch?
  end

  def create?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      user.owner? ? relation : relation.joins(measurement_profile: :customer).where(customers: { branch_id: current_branch_id })
    end
  end

  private

  def permitted_role?
    user.owner? || user.manager? || user.receptionist?
  end

  def accessible_branch?
    same_shop? && (user.owner? || record.branch.id == current_branch_id)
  end
end
