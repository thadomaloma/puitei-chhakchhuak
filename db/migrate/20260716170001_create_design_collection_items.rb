class CreateDesignCollectionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :design_collection_items do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :design_collection, null: false, foreign_key: true
      t.references :design, null: false, foreign_key: true
      t.references :added_by, null: false, foreign_key: { to_table: :users }
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :design_collection_items, [ :design_collection_id, :design_id ], unique: true,
      name: "index_design_collection_items_on_collection_and_design"
    add_index :design_collection_items, [ :shop_id, :design_id ],
      name: "index_design_collection_items_on_shop_and_design"
    add_index :design_collection_items, [ :design_collection_id, :position, :id ],
      name: "index_design_collection_items_on_collection_position"
    add_check_constraint :design_collection_items, "position >= 0", name: "design_collection_items_position_nonnegative"
  end
end
