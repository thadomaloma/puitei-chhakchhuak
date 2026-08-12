# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  def index?
    user.active? && (user.owner? || user.manager?)
  end

  def export?
    index?
  end
end
