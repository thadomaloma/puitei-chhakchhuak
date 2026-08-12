class DesignSharesController < ApplicationController
  before_action :set_share, only: %i[show destroy]
  before_action :load_form_data, only: %i[new create]

  def index
    authorize DesignShare
    @design_shares = policy_scope(DesignShare).includes(:customer, :created_by, :design_collection, :design_share_items).recent_first
  end

  def show
    authorize @design_share
  end

  def new
    @design_share = current_shop.design_shares.new(
      customer: @selected_customer, design_collection: @selected_collection,
      expires_at: DesignShare::DEFAULT_EXPIRY.from_now, allow_feedback: true
    )
    authorize @design_share
  end

  def create
    @design_share = current_shop.design_shares.new(share_params)
    @design_share.created_by = current_user
    authorize @design_share
    designs = shareable_designs
    raise ActiveRecord::RecordInvalid.new(@design_share) if designs.empty?

    DesignShare.transaction do
      @design_share.save!
      designs.each_with_index do |design, position|
        @design_share.design_share_items.create!(shop: current_shop, design: design, position: position)
      end
    end
    @share_url = public_design_share_url(token: @design_share.raw_token)
    render :show, status: :created
  rescue ActiveRecord::RecordInvalid => error
    @design_share ||= current_shop.design_shares.new(share_params)
    @design_share.errors.add(:base, error.message)
    render :new, status: :unprocessable_content
  end

  def destroy
    authorize @design_share
    @design_share.revoke!
    redirect_to design_shares_path, notice: t("design_shares.revoked")
  end

  private

  def set_share
    @design_share = policy_scope(DesignShare)
      .includes(:customer, :created_by, :design_collection, design_share_items: { design: { images_attachments: :blob } })
      .find(params[:id])
  end

  def load_form_data
    @customers = policy_scope(Customer).active.order(:full_name)
    @designs = policy_scope(Design).active.visibility_customer_shareable.recent_first.with_attached_images
    @collections = policy_scope(DesignCollection).active.visibility_customer_shareable.ordered
    @selected_customer = @customers.find_by(id: params[:customer_id])
    @selected_collection = @collections.find_by(id: params[:design_collection_id])
  end

  def shareable_designs
    ids = Array(params[:design_ids]).filter_map { |id| Integer(id, exception: false) }.uniq
    if @design_share.design_collection
      ids |= @design_share.design_collection.designs.active.visibility_customer_shareable.pluck(:id)
    end
    policy_scope(Design).active.visibility_customer_shareable.where(id: ids).order(:id)
  end

  def share_params
    params.require(:design_share).permit(:customer_id, :design_collection_id, :title, :message, :expires_at, :allow_feedback)
  end
end
