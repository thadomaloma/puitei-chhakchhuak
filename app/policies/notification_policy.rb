class NotificationPolicy < ApplicationPolicy
  def index?
    user.active?
  end

  def update?
    user.active? && record.recipient_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(recipient_id: user.id)
    end
  end
end
