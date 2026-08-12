# frozen_string_literal: true

class BranchPolicy < ApplicationPolicy
  def show?
    record.shop_id == current_shop_id && (user.owner? || record.id == current_branch_id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = scope.where(shop_id: current_shop_id)
      user.owner? ? relation : relation.where(id: current_branch_id)
    end
  end
end
