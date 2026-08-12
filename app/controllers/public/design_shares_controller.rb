module Public
  class DesignSharesController < ApplicationController
    skip_before_action :authenticate_user!
    skip_after_action :verify_authorized
    layout "public"

    rate_limit to: 60, within: 1.minute, only: %i[show feedback], with: -> { head :too_many_requests }

    def show
      return unless load_share

      @design_share.record_view!
    end

    def feedback
      return unless load_share
      head :forbidden and return unless @design_share.allow_feedback?

      item = @design_share.design_share_items.find_signed!(params[:item_token], purpose: :design_share_feedback)
      item.update!(feedback_params.merge(responded_at: Time.current))
      redirect_to public_design_share_path(token: params[:token], anchor: "design-#{item.id}"),
        notice: I18n.t("public_design_shares.feedback_saved")
    end

    private

    def load_share
      scope = DesignShare.active.includes(:customer, shop: { logo_attachment: :blob },
        design_share_items: { design: { images_attachments: :blob } })
      @design_share = scope.find_by(token_digest: DesignShare.digest(params[:token]))
      if @design_share
        public_items = @design_share.design_share_items.select do |item|
          item.design.active? && item.design.visibility_customer_shareable?
        end
        @design_share.design_share_items.target.replace(public_items)
        return true if public_items.any?
      end

      render :unavailable, status: :gone
      false
    end

    def feedback_params
      params.require(:design_share_item).permit(:customer_reaction, :customer_comment)
    end
  end
end
