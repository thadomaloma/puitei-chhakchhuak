class CreateDesigns < ActiveRecord::Migration[8.1]
  def change
    create_table :designs do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.references :rights_confirmed_by, null: false, foreign_key: { to_table: :users }
      t.references :primary_image_blob, foreign_key: { to_table: :active_storage_blobs }
      t.string :title, null: false
      t.text :description
      t.string :garment_type, null: false
      t.integer :visibility, null: false, default: 0
      t.integer :source_type, null: false, default: 0
      t.string :source_name
      t.string :source_url
      t.string :colour_family
      t.string :fabric_type
      t.string :embroidery_style
      t.string :sleeve_style
      t.string :neck_style
      t.string :occasion
      t.string :tags, array: true, default: [], null: false
      t.decimal :estimated_price, precision: 12, scale: 2
      t.integer :estimated_minutes
      t.text :internal_notes
      t.boolean :active, null: false, default: true
      t.datetime :rights_confirmed_at, null: false
      t.timestamps
    end

    add_index :designs, [ :shop_id, :active, :created_at ], order: { created_at: :desc }
    add_index :designs, [ :shop_id, :garment_type, :active ]
    add_index :designs, [ :shop_id, :visibility, :active ]
    add_index :designs, :tags, using: :gin
    add_check_constraint :designs, "length(trim(title)) > 0", name: "designs_title_present"
    add_check_constraint :designs, "garment_type ~ '^[a-z0-9_]+$'", name: "designs_garment_type_format"
    add_check_constraint :designs, "visibility >= 0 AND visibility <= 2", name: "designs_visibility_range"
    add_check_constraint :designs, "source_type >= 0 AND source_type <= 3", name: "designs_source_type_range"
    add_check_constraint :designs, "estimated_price IS NULL OR estimated_price >= 0", name: "designs_estimated_price_nonnegative"
    add_check_constraint :designs, "estimated_minutes IS NULL OR estimated_minutes > 0", name: "designs_estimated_minutes_positive"
  end
end
