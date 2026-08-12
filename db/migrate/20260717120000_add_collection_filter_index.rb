class AddCollectionFilterIndex < ActiveRecord::Migration[8.0]
  def change
    add_index :design_collections, [ :shop_id, :visibility, :active, :position, :id ],
      name: "index_design_collections_on_shop_visibility_active_position"
  end
end
