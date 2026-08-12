# frozen_string_literal: true

class ProductionPolicy < ApplicationPolicy
  def index?
    user.active?
  end
end
