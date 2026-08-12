# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  private

  def current_membership
    Current.membership&.user_id == user.id ? Current.membership : user.primary_membership
  end

  def current_shop_id
    Current.shop&.id || current_membership&.shop_id
  end

  def current_shop
    Current.shop || current_membership&.shop
  end

  def current_branch_id
    Current.branch&.id || current_membership&.branch_id || user.branch_id
  end

  def same_shop?
    record_shop_id = if record.respond_to?(:shop_id)
      record.shop_id || record.try(:branch)&.shop_id || record.try(:order)&.try(:shop_id)
    end
    record_shop_id.present? && record_shop_id == current_shop_id
  end

  def accessible_tenant_branch?
    same_shop? && (user.owner? || record.try(:branch_id) == current_branch_id || record.try(:branch)&.id == current_branch_id)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope

    def current_membership
      Current.membership&.user_id == user.id ? Current.membership : user.primary_membership
    end

    def current_shop_id
      Current.shop&.id || current_membership&.shop_id
    end

    def current_shop
      Current.shop || current_membership&.shop
    end

    def current_branch_id
      Current.branch&.id || current_membership&.branch_id || user.branch_id
    end

    def tenant_scope
      current_shop_id ? scope.where(shop_id: current_shop_id) : scope.none
    end
  end
end
