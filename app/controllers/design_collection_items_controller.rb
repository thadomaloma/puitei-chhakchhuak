class DesignCollectionItemsController < ApplicationController
  before_action :set_collection

  def new
    authorize @design_collection, :manage_items?
    designs = policy_scope(Design).active.search(params[:query])
      .where.not(id: @design_collection.designs.select(:id))
    designs = designs.where(garment_type: params[:garment_type]) if garment_type_allowed?(params[:garment_type])
    if params[:favourites] == "1"
      designs = designs.where(id: current_user.design_favourites.where(shop: current_shop).select(:design_id))
    end
    designs = designs.where("designs.tags @> ARRAY[?]::varchar[]", params[:tag]) if params[:tag].present?
    @garment_templates = MeasurementTemplate.active.alphabetical
    @tag_options = policy_scope(Design).active.unscope(:order)
      .select("DISTINCT unnest(tags) AS filter_tag").map(&:filter_tag).sort
    @filtered_count = designs.count
    @pagy, @designs = pagy(:offset, designs.recent_first.with_attached_images, limit: 24)
  end

  def create
    authorize @design_collection, :manage_items?
    design_ids = Array(params[:design_ids]).filter_map { |id| Integer(id, exception: false) }.uniq
    designs = policy_scope(Design).active.where(id: design_ids).order(:id)
    added_count = add_designs(designs)

    if added_count.positive?
      redirect_to @design_collection, notice: t("design_collections.designs_added", count: added_count)
    else
      redirect_to new_design_collection_design_collection_item_path(@design_collection),
        alert: t("design_collections.no_designs_added")
    end
  end

  def destroy
    authorize @design_collection, :manage_items?
    item = @design_collection.design_collection_items.find(params[:id])

    DesignCollection.transaction do
      @design_collection.lock!
      @design_collection.update!(cover_design: nil) if @design_collection.cover_design_id == item.design_id
      item.destroy!
    end
    redirect_to @design_collection, notice: t("design_collections.design_removed")
  end

  private

  def set_collection
    @design_collection = policy_scope(DesignCollection).find(params[:design_collection_id])
  end

  def garment_type_allowed?(value)
    value.present? && MeasurementTemplate.active.exists?(garment_type: value)
  end

  def add_designs(designs)
    added_count = 0
    next_position = @design_collection.design_collection_items.maximum(:position).to_i + 1

    DesignCollectionItem.transaction do
      designs.each do |design|
        item = @design_collection.design_collection_items.find_or_initialize_by(design: design)
        next unless item.new_record?

        item.assign_attributes(shop: current_shop, added_by: current_user, position: next_position)
        item.save!
        next_position += 1
        added_count += 1
      end
    end

    added_count
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
