# frozen_string_literal: true

class DashboardPolicy < Struct.new(:user, :dashboard)
  def show?
    user.present? && user.active?
  end
end
