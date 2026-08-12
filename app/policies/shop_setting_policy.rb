# frozen_string_literal: true

class ShopSettingPolicy < ApplicationPolicy
  def show?
    same_shop? && user.owner?
  end

  def update?
    show?
  end
end
