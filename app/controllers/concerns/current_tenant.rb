module CurrentTenant
  extend ActiveSupport::Concern

  included do
    before_action :set_current_tenant, if: -> { user_signed_in? && !devise_controller? }
    helper_method :current_shop, :current_membership, :current_branch
  end

  private

  def set_current_tenant
    membership = current_user.memberships.active.joins(:branch).merge(Branch.active)
      .includes(:shop, branch: :shop_setting).find_by(shop: Shop.current)

    unless membership
      Current.reset
      skip_authorization
      sign_out current_user
      redirect_to new_user_session_path, alert: I18n.t("saas.membership_required")
      return
    end

    Current.membership = membership
  end

  def current_shop
    Current.shop
  end

  def current_membership
    Current.membership
  end

  def current_branch
    Current.branch
  end
end
