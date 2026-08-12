# frozen_string_literal: true

class OrderPolicy < ApplicationPolicy
  def index?
    user.active?
  end

  def show?
    user.active? && accessible_branch?
  end

  def create?
    user.owner? || user.manager? || user.receptionist?
  end

  def confirm?
    create? && accessible_branch? && record.draft?
  end

  def job_card?
    show?
  end

  def qr_code?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      relation = tenant_scope
      user.owner? ? relation : relation.where(branch_id: current_branch_id)
    end
  end

  private

  def accessible_branch?
    accessible_tenant_branch?
  end
end
