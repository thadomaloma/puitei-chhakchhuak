class DesignsController < ApplicationController
  before_action :set_design, only: %i[show edit update archive]
  before_action :set_garment_templates, only: %i[index new create edit update]

  def index
    authorize Design
    designs = policy_scope(Design).search(params[:query])
    designs = designs.where(active: true) unless params[:archived] == "1"
    designs = designs.where(garment_type: params[:garment_type]) if garment_type_allowed?(params[:garment_type])
    designs = designs.where(visibility: params[:visibility]) if Design.visibilities.key?(params[:visibility])
    designs = designs.where(source_type: params[:source_type]) if Design.source_types.key?(params[:source_type])
    designs = apply_advanced_filters(designs)
    designs = designs.where(id: current_user.design_favourites.where(shop: current_shop).select(:design_id)) if params[:favourites] == "1"

    @filters_active = params.values_at(:query, :garment_type, :visibility, :source_type, :colour_family,
      :fabric_type, :occasion, :tag).any?(&:present?) || params[:archived] == "1" || params[:favourites] == "1"
    @filtered_count = designs.count
    @pagy, @designs = pagy(:offset, designs.recent_first.with_attached_images, limit: 24)
    scoped = policy_scope(Design)
    @design_count = scoped.active.count
    @shareable_count = scoped.active.where(visibility: :customer_shareable).count
    @garment_count = scoped.active.distinct.count(:garment_type)
    @favourites_by_design_id = current_user.design_favourites.where(shop: current_shop, design_id: @designs.map(&:id)).index_by(&:design_id)
    @advanced_filter_options = advanced_filter_options(scoped.active)
  end

  def show
    authorize @design
    @favourite = current_user.design_favourites.find_by(shop: current_shop, design: @design)
    @design_selections = if policy(DesignSelection).index?
      policy_scope(DesignSelection).active.where(design: @design)
        .where(customer_id: policy_scope(Customer).select(:id)).includes(:customer).recent_first
    else
      DesignSelection.none
    end
  end

  def new
    @design = current_shop.designs.new(visibility: :private, source_type: :original)
    authorize @design
  end

  def create
    @design = current_shop.designs.new(design_params)
    @design.uploaded_by = current_user
    @design.rights_confirmed_by = current_user
    @design.rights_confirmed_at = Time.current if rights_confirmed?
    authorize @design

    if @design.save
      set_primary_image(@design)
      redirect_to @design, notice: t("designs.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @design
  end

  def update
    authorize @design
    @design.assign_attributes(design_params)
    @design.remove_image_ids = requested_removal_ids

    if @design.save
      remove_requested_images
      set_primary_image(@design)
      redirect_to @design, notice: t("designs.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def archive
    authorize @design, :archive?
    Design.transaction do
      current_shop.design_collections.where(cover_design_id: @design.id)
        .update_all(cover_design_id: nil, updated_at: Time.current)
      @design.update!(active: false)
    end
    redirect_to designs_path, notice: t("designs.archived")
  end

  private

  def set_design
    @design = policy_scope(Design).with_attached_images.find(params[:id])
  end

  def set_garment_templates
    @garment_templates = MeasurementTemplate.active.alphabetical
  end

  def design_params
    permitted = params.require(:design).permit(
      :title, :description, :garment_type, :visibility, :source_type, :source_name, :source_url,
      :colour_family, :fabric_type, :embroidery_style, :sleeve_style, :neck_style, :occasion,
      :tag_list, :estimated_price, :estimated_minutes, :internal_notes, images: []
    )
    permitted.delete(:visibility) if permitted[:visibility] == "platform_library"
    permitted
  end

  def rights_confirmed?
    params.dig(:design, :rights_confirmed) == "1"
  end

  def requested_removal_ids
    Array(params.dig(:design, :remove_image_ids)).reject(&:blank?)
  end

  def remove_requested_images
    attachments = @design.images.attachments.where(id: requested_removal_ids)
    removing_primary = attachments.any? { |attachment| attachment.blob_id == @design.primary_image_blob_id }
    @design.update_column(:primary_image_blob_id, nil) if removing_primary
    attachments.each(&:purge)
  end

  def set_primary_image(design)
    requested_id = params.dig(:design, :primary_image_attachment_id)
    attachment = design.images.attachments.find_by(id: requested_id) if requested_id.present?
    attachment ||= design.primary_image_attachment
    design.update_column(:primary_image_blob_id, attachment.blob_id) if attachment && design.primary_image_blob_id != attachment.blob_id
  end

  def garment_type_allowed?(value)
    value.present? && @garment_templates.any? { |template| template.garment_type == value }
  end

  def apply_advanced_filters(designs)
    %i[colour_family fabric_type occasion].each do |attribute|
      designs = designs.where(attribute => params[attribute]) if params[attribute].present?
    end
    designs = designs.where("designs.tags @> ARRAY[?]::varchar[]", params[:tag]) if params[:tag].present?
    designs
  end

  def advanced_filter_options(scope)
    {
      colour_family: scope.where.not(colour_family: [ nil, "" ]).distinct.order(:colour_family).pluck(:colour_family),
      fabric_type: scope.where.not(fabric_type: [ nil, "" ]).distinct.order(:fabric_type).pluck(:fabric_type),
      occasion: scope.where.not(occasion: [ nil, "" ]).distinct.order(:occasion).pluck(:occasion),
      tag: scope.unscope(:order).select("DISTINCT unnest(tags) AS filter_tag").map(&:filter_tag).sort
    }
  end
end
