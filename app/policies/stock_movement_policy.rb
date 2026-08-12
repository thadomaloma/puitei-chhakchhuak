# frozen_string_literal: true

class StockMovementPolicy < ApplicationPolicy
  def create?
    return false unless user.active? && accessible_branch? && record.inventory_item&.active?
    return true if user.owner? || user.manager?

    case record.movement_type
    when "reservation", "release"
      user.receptionist?
    when "stock_out", "wastage", "consumption"
      user.cutting_staff? || user.tailor?
    else
      false
    end
  end

  private

  def accessible_branch?
    record.inventory_item&.shop_id == current_shop_id && (user.owner? || record.inventory_item&.branch_id == current_branch_id)
  end
end
