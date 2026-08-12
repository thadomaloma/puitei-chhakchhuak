class CreateDesignCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :design_collections do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :description
      t.integer :visibility, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.integer :design_collection_items_count, null: false, default: 0
      t.timestamps
    end

    add_index :design_collections, "shop_id, lower(name)", unique: true, where: "active",
      name: "index_active_design_collections_on_shop_and_lower_name"
    add_index :design_collections, [ :shop_id, :active, :position, :id ],
      name: "index_design_collections_on_shop_active_position"
    add_check_constraint :design_collections, "length(trim(name)) > 0", name: "design_collections_name_present"
    add_check_constraint :design_collections, "visibility >= 0 AND visibility <= 2", name: "design_collections_visibility_range"
    add_check_constraint :design_collections, "position >= 0", name: "design_collections_position_nonnegative"
    add_check_constraint :design_collections, "design_collection_items_count >= 0", name: "design_collections_count_nonnegative"
  end
end
