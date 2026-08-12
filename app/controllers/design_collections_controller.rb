class DesignCollectionsController < ApplicationController
  before_action :set_collection, only: %i[show edit update set_cover archive restore]
  before_action :set_garment_templates, only: :show
  before_action :set_cover_design, only: %i[show edit update]

  def index
    authorize DesignCollection
    normalize_index_filters
    collection_scope = policy_scope(DesignCollection)
    collections = collection_scope.search(@query)
    collections = case @status
    when "archived" then collections.where(active: false)
    when "all" then collections
    else collections.active
    end
    collections = collections.where(visibility: @visibility) if @visibility
    collections = collections.ordered
    @total_count = collection_scope.active.count
    @archived_count = collection_scope.archived.count
    @can_create_collection = policy(DesignCollection).create?
    @collections_exist = (@total_count + @archived_count).positive?
    @filters_active = @query.present? || @visibility.present? || @status != "active"
    @pagy, @design_collections = pagy(:offset, collections, limit: 16)
    @filtered_count = @pagy.count
    @cover_designs = cover_designs_for(@design_collections)
  end

  def show
    authorize @design_collection
    normalize_design_filters
    designs = @design_collection.designs.merge(policy_scope(Design)).active.search(@query)
    designs = designs.where(garment_type: @garment_type) if @garment_type
    @filters_active = @query.present? || @garment_type.present?
    @filtered_count = designs.count
    @pagy, @designs = pagy(:offset, designs.recent_first.with_attached_images, limit: 24)
    @collection_items = @design_collection.design_collection_items.where(design_id: @designs.map(&:id)).index_by(&:design_id)
  end

  def new
    @design_collection = current_shop.design_collections.new(visibility: :private)
    authorize @design_collection
  end

  def create
    @design_collection = current_shop.design_collections.new(collection_params)
    @design_collection.created_by = current_user
    authorize @design_collection

    if @design_collection.save
      redirect_to @design_collection, notice: t("design_collections.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @design_collection
  end

  def update
    authorize @design_collection

    if @design_collection.update(collection_params)
      redirect_to @design_collection, notice: t("design_collections.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def set_cover
    authorize @design_collection, :set_cover?
    design = eligible_cover_design if params[:design_id].present?

    if @design_collection.update(cover_design: design)
      redirect_to @design_collection, notice: t(design ? "design_collections.cover_updated" : "design_collections.cover_automatic")
    else
      redirect_to @design_collection, alert: @design_collection.errors.full_messages.to_sentence
    end
  end

  def archive
    authorize @design_collection, :archive?
    @design_collection.archive!
    redirect_to design_collections_path, notice: t("design_collections.archived")
  end

  def restore
    authorize @design_collection, :restore?
    @design_collection.restore!
    redirect_to @design_collection, notice: t("design_collections.restored")
  rescue ActiveRecord::RecordInvalid => error
    redirect_to design_collections_path(status: "archived"), alert: error.record.errors.full_messages.to_sentence
  end

  private

  def normalize_index_filters
    @query = DesignCollection.normalize_search_query(params[:query])
    @status = params[:status].to_s.presence_in(DesignCollection::FILTER_STATUSES) ||
      DesignCollection::DEFAULT_FILTER_STATUS
    @visibility = params[:visibility].to_s.presence_in(DesignCollection.visibilities.keys)
    @filter_params = {
      query: @query.presence,
      status: (@status unless @status == DesignCollection::DEFAULT_FILTER_STATUS),
      visibility: @visibility
    }.compact
  end

  def normalize_design_filters
    @query = Design.normalize_search_query(params[:query])
    requested_garment_type = params[:garment_type].to_s
    @garment_type = requested_garment_type if garment_type_allowed?(requested_garment_type)
    @filter_params = { query: @query.presence, garment_type: @garment_type }.compact
  end

  def set_collection
    @design_collection = policy_scope(DesignCollection).find(params[:id])
  end

  def set_garment_templates
    @garment_templates = MeasurementTemplate.active.alphabetical
  end

  def set_cover_design
    @cover_design = cover_designs_for([ @design_collection ])[@design_collection.id]
  end

  def collection_params
    params.require(:design_collection).permit(:name, :description, :visibility)
  end

  def garment_type_allowed?(value)
    value.present? && @garment_templates.any? { |template| template.garment_type == value }
  end

  def cover_designs_for(collections)
    DesignCollectionCoversQuery.new(
      collections: collections,
      item_scope: current_shop.design_collection_items,
      design_scope: policy_scope(Design)
    ).call
  end

  def eligible_cover_design
    @design_collection.designs
      .reorder(nil)
      .merge(policy_scope(Design).active)
      .joins(:images_attachments)
      .distinct
      .find(params[:design_id])
  end
end
