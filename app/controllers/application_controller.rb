class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Method

  before_action :authenticate_user!
  include CurrentTenant
  around_action :use_branch_locale, if: :user_signed_in?
  after_action :verify_authorized, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def use_branch_locale(&block)
    locale = current_branch&.shop_setting&.locale || current_branch&.locale || I18n.default_locale
    zone = current_branch&.time_zone || Time.zone.name
    I18n.with_locale(locale) { Time.use_zone(zone, &block) }
  end

  def user_not_authorized
    redirect_back fallback_location: root_path, alert: t("authorization.denied")
  end
end
