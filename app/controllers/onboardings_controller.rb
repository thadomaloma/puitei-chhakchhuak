class OnboardingsController < ApplicationController
  def show
    @shop = current_shop
    @branch = current_branch
    @settings = @branch.shop_setting
    authorize @shop, :update?
  end

  def update
    @shop = current_shop
    @branch = current_branch
    @settings = @branch.shop_setting
    authorize @shop, :update?

    ApplicationRecord.transaction do
      @shop.update!(shop_params.merge(onboarding_completed_at: Time.current))
      @branch.update!(branch_params.merge(name: @shop.name))
      @settings.update!(settings_params.merge(shop_name: @shop.name))
      BusinessAuditEvent.record!(action: "shop.onboarding_completed", shop: @shop, actor: current_user, auditable: @shop)
    end
    redirect_to root_path, notice: t("saas.onboarding_completed")
  rescue ActiveRecord::RecordInvalid => error
    error.record.errors.full_messages.each { |message| @shop.errors.add(:base, message) }
    render :show, status: :unprocessable_content
  end

  private

  def shop_params
    params.require(:shop).permit(:name, :country)
  end

  def branch_params
    params.require(:shop).permit(:phone, :email, :address, :locale, :time_zone)
  end

  def settings_params
    params.require(:shop).permit(:phone, :whatsapp_number, :email, :address, :currency, :measurement_unit, :invoice_prefix, :locale, :default_delivery_days)
  end
end
