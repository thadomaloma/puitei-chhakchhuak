class PaymentSettingsController < ApplicationController
  before_action :set_shop_setting

  def show
    authorize @shop_setting
  end

  def update
    authorize @shop_setting

    ApplicationRecord.transaction do
      @shop_setting.update!(payment_setting_params)
      BusinessAuditEvent.record!(
        action: "payment_profile.updated",
        shop: current_shop,
        actor: current_user,
        auditable: @shop_setting,
        metadata: { branch_id: current_branch.id, fields: changed_payment_fields }
      )
    end

    redirect_to payment_setting_path, notice: t("payment_settings.updated")
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_content
  end

  private

  def set_shop_setting
    @shop_setting = current_branch.shop_setting
  end

  def payment_setting_params
    params.require(:shop_setting).permit(:upi_id, :gpay_number)
  end

  def changed_payment_fields
    @shop_setting.saved_changes.keys & %w[upi_id gpay_number]
  end
end
