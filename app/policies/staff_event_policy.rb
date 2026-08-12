# frozen_string_literal: true

class StaffEventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      return relation if user.owner?
      return relation.where(branch_id: current_branch_id) if user.manager?

      relation.where(staff_member_id: user.id)
    end
  end
end
