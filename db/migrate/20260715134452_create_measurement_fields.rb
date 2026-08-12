class CreateMeasurementFields < ActiveRecord::Migration[8.1]
  def change
    create_table :measurement_fields do |t|
      t.references :measurement_template, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.integer :position, null: false, default: 0
      t.boolean :required, null: false, default: false

      t.timestamps
    end


    add_index :measurement_fields, [ :measurement_template_id, :key ], unique: true
    add_index :measurement_fields, [ :measurement_template_id, :position ]
    add_check_constraint :measurement_fields, "key ~ '^[a-z][a-z0-9_]*$'", name: "measurement_fields_key_format"
    add_check_constraint :measurement_fields, "position >= 0", name: "measurement_fields_position"
  end
end
