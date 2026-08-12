class Current < ActiveSupport::CurrentAttributes
  attribute :user, :shop, :membership, :branch

  def membership=(membership)
    super
    self.user = membership&.user
    self.shop = membership&.shop
    self.branch = membership&.branch
  end
end
