class DesignCollectionCoversQuery
  def initialize(collections:, item_scope:, design_scope:)
    @collections = Array(collections)
    @item_scope = item_scope
    @design_scope = design_scope
  end

  def call
    return {} if collections.empty?

    eligible_ids = eligible_design_ids_by_collection
    chosen_ids = collections.to_h do |collection|
      candidates = eligible_ids.fetch(collection.id, [])
      manual_id = collection.cover_design_id if candidates.include?(collection.cover_design_id)
      [ collection.id, manual_id || candidates.first ]
    end

    designs = design_scope.where(id: chosen_ids.values.compact).with_attached_images.index_by(&:id)
    chosen_ids.transform_values { |design_id| designs[design_id] }
  end

  private

  attr_reader :collections, :item_scope, :design_scope

  def eligible_design_ids_by_collection
    rows = item_scope
      .joins(design: :images_attachments)
      .merge(design_scope.active)
      .where(design_collection_id: collections.map(&:id))
      .order(:design_collection_id, :position, :id)
      .pluck(:design_collection_id, :design_id)

    rows.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(collection_id, design_id), result|
      result[collection_id] << design_id unless result[collection_id].include?(design_id)
    end
  end
end
