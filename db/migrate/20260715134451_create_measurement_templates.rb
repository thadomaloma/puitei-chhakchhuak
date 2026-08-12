class CreateMeasurementTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :measurement_templates do |t|
      t.string :name, null: false
      t.string :garment_type, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end


    add_index :measurement_templates, :garment_type, unique: true
    add_check_constraint :measurement_templates, "garment_type ~ '^[a-z0-9_]+$'", name: "measurement_templates_garment_type_format"
  end
end
